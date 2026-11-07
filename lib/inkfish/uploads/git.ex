defmodule Inkfish.Uploads.Git do
  alias Inkfish.Sandbox.TempFs
  alias Inkfish.Uploads
  alias Inkfish.Uploads.Upload

  # The staging directory the clone script copies its results into carries this
  # prefix; see `staging_dir/3`.
  @staging_prefix "inkfish-clone-"

  @doc """
  Reads the cloned repository metadata (remote origin URL and commit SHA)
  from the unpacked checkout's `.git` directory. Returns `nil` when the
  checkout is not a git repository (e.g. a regular file upload).
  """
  def repo_info(unpacked_path) do
    with {:ok, url} <- repo_url(unpacked_path),
         {:ok, commit} <- repo_commit(unpacked_path) do
      %{url: url, commit: commit}
    else
      _ -> nil
    end
  end

  defp repo_url(unpacked_path) do
    config = Path.join([unpacked_path, ".git", "config"])

    with {:ok, text} <- File.read(config) do
      origin_url =
        text
        |> String.split("\n")
        |> parse_config_url()

      if origin_url, do: {:ok, origin_url}, else: :error
    else
      _ -> :error
    end
  end

  defp repo_commit(unpacked_path) do
    shallow = Path.join([unpacked_path, ".git", "shallow"])

    case File.read(shallow) do
      {:ok, text} ->
        case String.split(text) do
          [sha | _] -> {:ok, sha}
          _ -> :error
        end

      _ ->
        fetch_head = Path.join([unpacked_path, ".git", "FETCH_HEAD"])

        case File.read(fetch_head) do
          {:ok, text} ->
            case String.split(text) do
              [sha | _] -> {:ok, sha}
              _ -> :error
            end

          _ ->
            :error
        end
    end
  end

  defp parse_config_url(lines, in_origin? \\ false)

  defp parse_config_url([], _in_origin?), do: nil

  defp parse_config_url(["[" <> rest | tail], _in_origin?) do
    in_origin? = rest =~ ~r/^remote "origin"\]/
    parse_config_url(tail, in_origin?)
  end

  defp parse_config_url([line | tail], true) do
    case Regex.run(~r/^\s*url\s*=\s*(.+)$/, line) do
      [_, url] -> url
      _ -> parse_config_url(tail, true)
    end
  end

  defp parse_config_url([_line | tail], false) do
    parse_config_url(tail, false)
  end

  def start_clone(url) do
    script =
      :code.priv_dir(:inkfish)
      |> Path.join("scripts/upload_git_clone.sh")

    env = [
      REPO: url,
      CLONE_SIZE: clone_size(),
      SUBMIT_SIZE: submit_size(),
      MAX_FILES: to_string(max_files()),
      BLOB_LIMIT: blob_limit(),
      GIT_IGNORE: Enum.join(ignore_list(), " "),
      GIT_ALLOW_PROTOCOL: allowed_protocols(),
      # We own the staging directory the script copies its results into, so we
      # create it here and hand the path over. That way we know it and can
      # remove it even when the script dies before it reports `dir:`/`tar:`.
      STAGE_DIR: make_staging_dir()
    ]

    # The script is plain: it expects its two mounts to exist, and this is what
    # makes them. `unshare_argv/3` is the same primitive the archive extraction
    # uses, so the `unshare` invocation and the mount preamble have exactly one
    # implementation. Ittys runs the argv itself, keeping its own supervision
    # and streaming; its `execve(2)` is why `unshare_argv/3` resolves the
    # binary to an absolute path.
    with {:ok, argv} <- TempFs.unshare_argv(clone_mounts(), "bash", [script]) do
      Inkfish.Ittys.run(argv, env)
    end
  end

  # The two tmpfs mounts the clone script runs inside, and the sizes they are
  # capped at. `unshare_argv/3` mounts them and exports their paths, which is
  # what the script's opening `: "${CLONE_TMP:?}"`/`: "${PERSIST_TMP:?}"`
  # assertions check for. The same sizes are handed to the script as
  # `CLONE_SIZE`/`SUBMIT_SIZE` for its config echo; the mounts are what enforce
  # them.
  #
  # The two budgets mean different things, which is why they are sized
  # differently:
  #
  #   * `CLONE_TMP` is the *checkout* budget (`:git_clone_size`). It holds the
  #     fetch's packfile and nothing else -- no working tree is materialized --
  #     and it is thrown away when the clone finishes. Spending 100 MiB here to
  #     find the 5 MiB worth keeping is exactly what it is for.
  #   * `PERSIST_TMP` is the *saved* budget (`:git_submit_size`): what the
  #     upload actually keeps. The script spends it as a count of saved *bytes*,
  #     but a tmpfs charges a full 4 KiB page per file, so the mount has to be
  #     larger than the byte budget or a many-file repository would run out of
  #     space on page granularity alone. It is sized here as the saved budget
  #     plus a page per allowed file (`:git_max_files`), plus a MiB for the
  #     trimmed `.git` metadata, and the kernel cap stays as the backstop
  #     behind the script's own accounting.
  @doc false
  def clone_mounts do
    clone_mounts(submit_size(), max_files())
  end

  # The same mounts for an explicit saved budget and file limit, which is what
  # the tests use: they exercise the production mount arithmetic instead of
  # hand-rolling an approximation of it.
  @doc false
  def clone_mounts(submit_size, max_files) do
    [
      {"CLONE_TMP", clone_size()},
      {"PERSIST_TMP", persist_mount_size(submit_size, max_files)}
    ]
  end

  # The staging directory the clone script copies its results out to. It is
  # created on the uploads filesystem -- not in the system temp dir -- so that
  # `create_upload/3` can move the checkout into place instead of copying it a
  # second time; see `copy_checkout/2`. It keeps the same prefix and name
  # shape a `mktemp -d` would produce, so `staging_dir/3` can recognise it.
  defp make_staging_dir do
    dir =
      Path.join(
        Upload.upload_base(),
        "#{@staging_prefix}#{Base.encode16(:crypto.strong_rand_bytes(6))}"
      )

    File.mkdir_p!(dir)
    dir
  end

  defp clone_size do
    Application.get_env(:inkfish, :git_clone_size, "100m")
  end

  defp submit_size do
    Application.get_env(:inkfish, :git_submit_size, "5m")
  end

  # The persistent mount's size: the saved budget, a 4 KiB page per file the
  # budget allows, and a MiB of slack for the trimmed `.git` metadata. A budget
  # this cannot read (a percentage of RAM, say) is passed through untouched --
  # tmpfs may well understand it even though the arithmetic here does not, and
  # silently replacing the operator's value with a guessed one would be worse
  # than not adding the overhead.
  @doc false
  def persist_mount_size(submit_size, max_files) do
    case size_kb(submit_size) do
      {:ok, kb} -> "#{kb + 4 * max_files + 1024}k"
      :error -> submit_size
    end
  end

  # How many files the saved checkout may hold. Each one costs a 4 KiB page of
  # the persistent tmpfs no matter how small it is, so this is the number that
  # decides whether a repository can be saved at all.
  defp max_files do
    Application.get_env(:inkfish, :git_max_files, 2000)
  end

  # The directories that are never the student's own work: installed
  # dependencies and build output. Matched against every path component.
  @default_ignore ~w(node_modules .pnpm bower_components .venv venv __pycache__
                     .tox .eggs .pytest_cache .mypy_cache .cache target dist
                     build .gradle .next .nuxt coverage)

  defp ignore_list do
    Application.get_env(:inkfish, :git_ignore, @default_ignore)
  end

  # The largest blob worth downloading: a blob bigger than the entire saved
  # budget can never be saved, so the fetch is told to leave it out
  # (`--filter=blob:limit=`). It defaults to the saved budget itself, because
  # nothing above that can ever fit. A server that does not support partial
  # clone only warns, and the fetch falls back to a plain depth-1 fetch.
  defp blob_limit do
    case Application.get_env(:inkfish, :git_blob_limit, :submit_size) do
      :submit_size ->
        case size_kb(submit_size()) do
          {:ok, _} -> submit_size()
          :error -> ""
        end

      value when is_binary(value) ->
        value

      _other ->
        ""
    end
  end

  # A tmpfs size string (`5m`, `512k`, `1048576`) as a number of KiB. Only used
  # for arithmetic on this side; the string itself is still what gets mounted.
  defp size_kb(size) do
    case Regex.run(~r/\A([0-9]+)([kKmMgG]?)\z/, size) do
      [_, digits, unit] ->
        n = String.to_integer(digits)

        kb =
          case String.downcase(unit) do
            "k" -> n
            "m" -> n * 1024
            "g" -> n * 1024 * 1024
            "" -> div(n, 1024)
          end

        {:ok, kb}

      _ ->
        :error
    end
  end

  defp allowed_protocols do
    Application.get_env(:inkfish, :git_allowed_protocols, "https:http:git")
  end

  def get_results(uuid) do
    {:ok, view} = Inkfish.Ittys.close(uuid)

    case parse_results(view.result) do
      {:ok, results} -> {:ok, results}
      {:error, :incomplete_results} -> {:error, failed_clone_reason(view)}
    end
  end

  @required_results ["dir", "tar"]

  def parse_results(text) do
    results =
      String.split(text, "\n", trim: true)
      |> Enum.reduce(%{}, fn line, acc ->
        case String.split(line, ~r/:\s*/, parts: 2) do
          [key, val] -> Map.put(acc, key, val)
          _ -> acc
        end
      end)

    if Enum.all?(@required_results, &Map.has_key?(results, &1)) do
      {:ok, results}
    else
      {:error, :incomplete_results}
    end
  end

  # `parse_results/1` only ever sees the script's marked stdout, so when the
  # script dies before printing `dir:`/`tar:` it can only report
  # `:incomplete_results` -- which tells the user nothing about what actually
  # went wrong. The real reason is already sitting in the itty view: git's own
  # message on stderr, whatever the script managed to print on stdout, and the
  # process exit status (plumbed through the view by `Inkfish.Ittys.Server`).
  # Every one of those is carried to the client verbatim; none of it is
  # synthesised, and the reason is never replaced with a generic sentence.
  defp failed_clone_reason(view) do
    err = view |> stream_text(:err) |> String.trim()
    out = view |> stream_text(:out) |> String.trim()
    status = exit_status_text(view)

    cond do
      err != "" -> join_reason([err, status])
      out != "" -> join_reason([out, status])
      status -> status
      true -> "clone failed with no output and no exit status"
    end
  end

  defp stream_text(view, stream) do
    case view.outputs do
      %{^stream => text} when is_binary(text) -> text
      _ -> ""
    end
  end

  # erlexec encodes the OS wait status in the DOWN message (the real exit code
  # sits in the high byte), so it is decoded with erlexec's own `status/1`
  # rather than shown raw: "exit status: 128", not "exit status: 32768".
  defp exit_status_text(view) do
    case Map.get(view, :exit_status) do
      {:exit_status, raw} when is_integer(raw) ->
        "exit status: #{decode_status(raw)}"

      {:exit_status, raw} ->
        "exit status: #{inspect(raw)}"

      nil ->
        nil

      other ->
        "exit status: #{inspect(other)}"
    end
  end

  defp decode_status(raw) do
    case :exec.status(raw) do
      {:status, code} -> to_string(code)
      {:signal, sig, true} -> "#{sig} (core dumped)"
      {:signal, sig, false} -> "killed by signal #{sig}"
    end
  end

  defp join_reason(parts) do
    parts
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  def create_upload(data, kind, user_id) do
    with {:ok, dir, tar} <- take_paths(data) do
      # `upload_git_clone.sh` copies its results out of the tmpfs mount
      # namespace into a host-visible staging directory and reports paths
      # inside that directory. The script cannot remove it itself -- callers
      # read the reported paths after it exits -- so we drop it once we have
      # copied everything out, including when the copy fails.
      stage = staging_dir(data, dir, tar)

      try do
        do_create_upload(dir, tar, kind, user_id)
      after
        remove_staging(stage)
      end
    end
  end

  defp do_create_upload(dir, tar, kind, user_id) do
    file_name = Path.basename(tar)
    size = Upload.file_size(tar)

    params = %{
      "kind" => kind,
      "user_id" => user_id,
      "name" => file_name,
      "size" => size
    }

    with {:ok, upload} <- create_upload_row(params),
         :ok <- copy_tarball(tar, upload),
         :ok <- copy_checkout(dir, upload) do
      {:ok, Upload.fetch_size(upload)}
    end
  end

  # A rejected insert used to raise out of the channel callback, leaving the
  # user with nothing but a crash log. The changeset's own messages are the
  # actionable reason, so they are rendered into the error the channel pushes.
  defp create_upload_row(params) do
    case Uploads.create_git_upload(params) do
      {:ok, upload} ->
        {:ok, upload}

      {:error, %Ecto.Changeset{} = cset} ->
        {:error, "could not record upload: " <> changeset_errors(cset)}

      {:error, reason} ->
        {:error, "could not record upload: #{inspect(reason)}"}
    end
  end

  # The staging directory is created on the uploads filesystem precisely so
  # these are moves: the checkout the script staged is already the tree we want,
  # and copying it again would double both the time and the disk the upload
  # takes. `File.rename/2` fails with `:exdev` when the staging directory is on
  # another filesystem (a `dir`/`tar` handed to us from somewhere else, as the
  # tests do), so the copy is still there as the fallback. A non-regular tarball
  # and a non-directory checkout keep going straight to the copy, which is what
  # reports the reason (`:eisdir`, `:enoent`, ...) when they are the wrong kind
  # of thing.
  defp copy_tarball(tar, upload) do
    dest = Upload.upload_path(upload)

    if File.regular?(tar) do
      move(tar, dest, fn -> copy_tarball_file(tar, dest) end)
    else
      copy_tarball_file(tar, dest)
    end
  end

  defp copy_tarball_file(tar, dest) do
    case File.cp(tar, dest) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "could not copy upload tarball #{tar} to #{dest}: #{reason}"}
    end
  end

  defp copy_checkout(dir, upload) do
    dest = Upload.unpacked_path(upload)

    if File.dir?(dir) do
      move(dir, dest, fn -> copy_checkout_dir(dir, dest) end)
    else
      copy_checkout_dir(dir, dest)
    end
  end

  defp copy_checkout_dir(dir, dest) do
    case File.cp_r(dir, dest) do
      {:ok, _files} ->
        :ok

      {:error, reason, file} ->
        {:error,
         "could not copy checkout #{dir} to #{dest}: #{reason} (#{file})"}
    end
  end

  defp move(src, dest, fallback) do
    case File.rename(src, dest) do
      :ok -> :ok
      {:error, _reason} -> fallback.()
    end
  end

  # `Ecto.Changeset.traverse_errors/2` keeps `%{...}` placeholders in the
  # message, so they are interpolated here the same way Phoenix's generated
  # `translate_errors/1` does. Field names and messages are both kept: they are
  # the specific reason, which is the whole point of the error.
  defp changeset_errors(%Ecto.Changeset{} = cset) do
    errors =
      cset
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)
      |> Enum.map_join("; ", fn {field, messages} ->
        "#{field}: #{Enum.join(messages, ", ")}"
      end)

    if errors == "", do: inspect(cset.errors), else: errors
  end

  # Prefer the staging directory the caller created and handed to the script
  # (`data["stage"]`); fall back to the directory the reported paths share when
  # the caller did not provide one (a script run that made its own `mktemp
  # -d`). Both reported paths live in that one directory, so removing it
  # reclaims the whole staging area. Only remove it when it really is ours: a
  # directory named `inkfish-clone-*` directly under one of the two places this
  # module has ever made one -- the upload base (where `make_staging_dir/0`
  # puts it now, so the results can be moved into place) and the system temp
  # dir (where older runs put it) -- that also holds the reported checkout and
  # tarball. A caller-supplied path we were handed some other way must never be
  # deleted.
  defp staging_dir(data, dir, tar) do
    stage = data["stage"] || Path.dirname(dir)

    if Path.dirname(tar) == stage and staging_parent?(stage) do
      stage
    else
      nil
    end
  end

  defp staging_parent?(stage) do
    expanded = Path.expand(stage)
    parent = Path.dirname(expanded)

    parent in [
      Path.expand(Upload.upload_base()),
      Path.expand(System.tmp_dir!())
    ] and
      String.starts_with?(Path.basename(expanded), @staging_prefix)
  end

  defp remove_staging(nil), do: :ok

  defp remove_staging(stage) do
    case File.rm_rf(stage) do
      {:ok, _} -> :ok
      {:error, _, _} -> :ok
    end
  end

  defp take_paths(data) do
    case {data["dir"], data["tar"]} do
      {dir, tar} when is_binary(dir) and is_binary(tar) -> {:ok, dir, tar}
      _ -> :error
    end
  end
end
