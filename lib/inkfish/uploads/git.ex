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
      GIT_ALLOW_PROTOCOL: allowed_protocols(),
      # The clone script runs the unprivileged helper itself, and resolves it
      # through TMPTMPFS_BIN exactly like TempFs.bin/0, so one setting points
      # both consumers at the same binary (the stale setuid helper at
      # /usr/local/bin/tmptmpfs does not implement `run`).
      TMPTMPFS_BIN: TempFs.bin(),
      # We own the staging directory the script copies its results into, so we
      # create it here and hand the path over. That way we know it and can
      # remove it even when the script dies before it reports `dir:`/`tar:`.
      STAGE_DIR: make_staging_dir()
    ]

    {:ok, _uuid} = Inkfish.Ittys.run(script, env)
  end

  # The staging directory the clone script copies its results out to. It keeps
  # the same prefix and location the script's own `mktemp -d` would use, so
  # `staging_dir/3` can recognise it (see the guard there).
  defp make_staging_dir do
    dir =
      Path.join(
        System.tmp_dir!(),
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

  defp copy_tarball(tar, upload) do
    dest = Upload.upload_path(upload)

    case File.cp(tar, dest) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "could not copy upload tarball #{tar} to #{dest}: #{reason}"}
    end
  end

  defp copy_checkout(dir, upload) do
    dest = Upload.unpacked_path(upload)

    case File.cp_r(dir, dest) do
      {:ok, _files} ->
        :ok

      {:error, reason, file} ->
        {:error,
         "could not copy checkout #{dir} to #{dest}: #{reason} (#{file})"}
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
  # directory named `inkfish-clone-*` directly under the temp dir that also
  # holds the reported checkout and tarball. A caller-supplied path we were
  # handed some other way must never be deleted.
  defp staging_dir(data, dir, tar) do
    stage = data["stage"] || Path.dirname(dir)
    tmp_dir = Path.expand(System.tmp_dir!())

    if Path.dirname(tar) == stage and
         Path.dirname(Path.expand(stage)) == tmp_dir and
         String.starts_with?(Path.basename(stage), @staging_prefix) do
      stage
    else
      nil
    end
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
