defmodule Inkfish.Sandbox.Archive do
  alias Inkfish.Sandbox
  alias Inkfish.Sandbox.SanitizeLinks
  alias Inkfish.Uploads.Upload
  alias Sandbox.TempFs
  alias Sandbox.Shell

  # The extraction pipeline -- mount the capped tmpfs, `tar --no-same-owner`
  # into it, copy the tree out to the staging directory -- runs inside one
  # `unshare` invocation, and so under one deadline. All of it is shell: no
  # Elixir runs inside the namespace any more, so the bound no longer has to
  # cover an Erlang VM boot. The in-process sanitize and the move into place
  # happen after it, outside this bound, as local filesystem work. Test config
  # lowers it so a broken mount still fails fast.
  @default_timeout_ms 30_000

  # Staging trees live under this directory inside the upload base; see
  # `staging_root/0`.
  @staging_subdir "staging"

  @doc """
  The directory staged trees are extracted into.

  It is under the upload base -- the same filesystem as every upload's final
  path, so the move out of it is a rename rather than a copy -- and it is not
  reachable from an upload id: `/uploads/:id/_meta/unpacked/*path` serves an
  upload's own unpacked tree, and nothing serves this.
  """
  def staging_root do
    Path.join(Upload.upload_base(), @staging_subdir)
  end

  @doc """
  Safely extract an archive file.

  Three steps, in this order, and this function owns all of them so no caller
  can leave one out:

    1. inside one `unshare` invocation: mount the size-capped tmpfs,
       `tar --no-same-owner` the archive into it, and `cp -r` the tree out to a
       fresh staging directory (see `staging_root/0`);
    2. sanitize the staged tree in this process, removing every symlink that
       escapes it;
    3. move the sanitized tree into `target` with a same-filesystem rename.

  The order is the point. The upload id is handed to the user, so the final
  path must never contain an escaping symlink -- not even for the instant
  between the unpack and the sanitize. That is why the tree is extracted to a
  staging directory no upload id can name, and why the move is a rename rather
  than a copy: the final path is either absent or fully sanitized.

  Returns `:ok`, or `{:error, reason}` when the mount, the unpacking, the
  sanitize or the move fails. A non-zero `tar` exit is fatal: extracting past
  the size cap leaves a silently truncated tree (a short file plus a zero-byte
  file), so a partial extraction must never be reported as a success. A
  timeout of the bounded pipeline is reported distinctly from an unpack
  failure.
  """
  def safe_extract(archive, target, max_size) do
    archive = Path.expand(archive)
    target = Path.expand(target)

    with {:ok, script} <- unpack(archive),
         {:ok, stage} <- make_stage_dir(),
         :ok <- unpack_into(stage, script, archive, max_size) do
      sanitize_and_move(stage, target)
    end
  end

  @doc """
  Remove every symlink under `base` that escapes it.
  """
  def sanitize_links!(base) do
    SanitizeLinks.sanitize_links!(base)
  end

  @doc """
  Remove `path` when it is a symlink that escapes `base`.
  """
  def sanitize_link!(path, base) do
    SanitizeLinks.sanitize_link!(path, base)
  end

  @doc """
  Choose how `archive` should be unpacked.

  Returns `{:ok, script}`, a shell script to run inside the tmpfs, or
  `{:error, reason}` when the archive kind is not supported.
  """
  def unpack(archive) do
    cond do
      Regex.match?(~r/\.tar\.(gz|xz|bz2)$/, archive) ->
        {:ok, untar_script()}

      Regex.match?(~r/\.zip$/, archive) ->
        {:error, "zip archives are not supported"}

      true ->
        {:ok, copy_script()}
    end
  end

  def tar(src, archive) do
    dir = Path.dirname(src)
    File.mkdir_p!(Path.dirname(archive))

    Shell.run_script("""
    cd "#{dir}" && tar czvf "#{archive}"
    """)
  end

  # A fresh random directory under the staging root. It must not be derivable
  # from the upload id: the id is handed to the user (and
  # `/uploads/:id/_meta/unpacked/*path` serves the unpacked tree), so a staging
  # path built from it would be a path the user could name. This one cannot be
  # guessed and no route serves it.
  defp make_stage_dir do
    root = staging_root()

    with :ok <- File.mkdir_p(root),
         stage = Path.join(root, random_name()),
         :ok <- File.mkdir_p(stage) do
      {:ok, canonical(stage)}
    else
      {:error, reason} ->
        {:error,
         "could not create the staging directory under #{root}: #{reason}"}
    end
  end

  defp random_name do
    Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  # The sanitizer compares `readlink -f` output -- always canonical -- against
  # its base as a *string*, so the base has to be canonical too, or every
  # in-tree relative symlink looks like an escape and is removed. `Path.expand/1`
  # is lexical and would not resolve a symlinked component (a symlinked `$HOME`,
  # say); `realpath -m` does, and `realpath(1)` is already required by the mount
  # preamble in `Inkfish.Sandbox.TempFs`.
  #
  # If `realpath` cannot be run the path is used as it is: that is the
  # conservative direction (some in-tree relative links may be removed), and it
  # is not worth failing an extraction over.
  defp canonical(path) do
    case System.cmd("realpath", ["-m", "--", path]) do
      {resolved, 0} -> String.trim(resolved)
      {_output, _status} -> path
    end
  end

  # The one `unshare` invocation: it mounts the capped tmpfs, unpacks into it,
  # and copies the tree out to the staging directory. `$TMPFS` exists only
  # inside the namespace that invocation creates, which is why the copy-out has
  # to happen there too.
  defp unpack_into(stage, script, archive, max_size) do
    case TempFs.run_in_one_tempfs(max_size, "bash", ["-c", script],
           env: script_env(archive, stage),
           timeout_ms: timeout_ms()
         ) do
      {:ok, _output} ->
        :ok

      {:error, reason} ->
        {:error, extraction_error(reason)}
    end
  end

  # `--no-same-owner` is required, not cosmetic: inside the namespace only uid 0
  # is mapped, so tar sees euid 0, decides it should restore the archive's
  # ownership, and fails with "Cannot change ownership to uid 1000: Invalid
  # argument", aborting the extraction.
  #
  # We `cd` into the mount rather than using `-C`: tar's refusal to follow links
  # that escape the working directory is what keeps a crafted archive from
  # writing outside the tmpfs. Do not add -P/--absolute-names or
  # -h/--dereference.
  #
  # `set -e` is what makes a non-zero `tar` exit fatal for the whole script, so
  # a truncated extraction never reaches the copy-out.
  defp untar_script do
    """
    set -euo pipefail
    cd "$TMPFS"
    tar xvf "$INKFISH_ARCHIVE" --no-same-owner >/dev/null
    cp -r "$TMPFS/." "$INKFISH_STAGE"
    """
  end

  # Copying `$TMPFS/.` includes dotfiles, unlike a `$TMPFS/*` glob.
  #
  # `cp -r` copies symlinks as symlinks (rather than following them) and does
  # not preserve ownership or setuid/setgid bits. Never use `cp -a`/`cp -p`
  # here: the archive's ownership is not ours to restore, and inside the
  # namespace it is not even mapped.
  defp copy_script do
    """
    set -euo pipefail
    cp "$INKFISH_ARCHIVE" "$TMPFS/$(basename "$INKFISH_ARCHIVE")"
    cp -r "$TMPFS/." "$INKFISH_STAGE"
    """
  end

  defp script_env(archive, stage) do
    [
      {"INKFISH_ARCHIVE", archive},
      {"INKFISH_STAGE", stage}
    ]
  end

  # Sanitize first, move second: the sanitized staging tree is what lands at the
  # final path, and it lands there in one step.
  defp sanitize_and_move(stage, target) do
    with :ok <- sanitize_stage(stage) do
      move_into_place(stage, target)
    end
  end

  # The sanitize is a plain in-process call now, and a raise out of it must not
  # escape `safe_extract/3`'s `{:ok, _} | {:error, _}` contract. It used to run
  # as its own OS process inside the namespace, where a raise became an exit
  # status and reached the caller as `{:error, reason}`; this keeps that shape,
  # with the raise's own message kept verbatim.
  defp sanitize_stage(stage) do
    sanitize_links!(stage)
    :ok
  rescue
    error -> {:error, Exception.message(error)}
  end

  # A same-filesystem `File.rename/2`, so the final path is either absent or the
  # whole sanitized tree -- never a half-copied one. Staging is under the upload
  # base (see `staging_root/0`) for exactly this reason; a caller whose target
  # is on another filesystem gets `:exdev` here, reported as a failure rather
  # than papered over with a copy.
  #
  # An existing target is removed first. `Upload.unpacked_path/1` `mkdir_p`s it
  # before we are called, and `rename(2)` onto an existing *empty* directory
  # succeeds while onto a non-empty one it fails with `:enotempty` -- and the
  # obvious fallback, copying the staged tree in, is the merge that can leave a
  # partial result behind. Removing it makes both cases the same: the target is
  # the sanitized tree, or it is gone.
  #
  # Cleanup is asymmetric on purpose. On success the move *is* the cleanup: the
  # staging directory is renamed into place, so nothing of ours is left behind.
  # On failure the staging directory is left exactly as it is, junk and all --
  # a delete path would have to run while we are already reporting a failure,
  # and leftover junk in a staging area that no route serves is preferable to
  # delete logic that can itself fail or, worse, delete the wrong thing.
  defp move_into_place(stage, target) do
    parent = Path.dirname(target)

    with :ok <- File.mkdir_p(parent),
         :ok <- remove_existing(target) do
      case File.rename(stage, target) do
        :ok ->
          :ok

        {:error, reason} ->
          {:error, "could not move the sanitized tree to #{target}: #{reason}"}
      end
    else
      {:error, reason} ->
        {:error,
         "could not prepare #{parent} for the sanitized tree: #{reason}"}
    end
  end

  defp remove_existing(target) do
    case File.lstat(target) do
      {:ok, _stat} ->
        case File.rm_rf(target) do
          {:ok, _removed} -> :ok
          {:error, reason, file} -> {:error, "#{reason} (#{file})"}
        end

      {:error, _reason} ->
        :ok
    end
  end

  # The mount's and `tar`'s own diagnostics (a mount error, a `tar` exit code
  # and output) are passed through as-is; only a timeout of the bounded call is
  # reported apart, so the two are not confused.
  defp extraction_error(reason) do
    if is_binary(reason) and String.contains?(reason, "timed out") do
      "timed out unpacking archive"
    else
      reason
    end
  end

  defp timeout_ms do
    Application.get_env(:inkfish, :extract_timeout_ms, @default_timeout_ms)
  end
end
