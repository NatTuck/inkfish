defmodule Inkfish.Sandbox.Archive do
  require Logger

  alias Inkfish.Sandbox
  alias Sandbox.TempFs
  alias Sandbox.Shell

  # `Inkfish.Sandbox.SanitizeLinks` is defined at runtime by
  # `priv/sandbox/sanitize_logic.exs` -- the single source of truth, shared with
  # the script that runs inside the namespace -- so the compiler cannot see it.
  @compile {:no_warn_undefined, Inkfish.Sandbox.SanitizeLinks}

  # Prefix the sanitizer puts on its own output inside the namespace. It is
  # re-logged here so that a warning produced inside the namespace still reaches
  # the caller's log -- and `capture_log` in the tests.
  @warning_prefix "INKFISH-SANITIZE "

  # The whole extraction pipeline -- mount, tar, Erlang VM boot, one `readlink
  # -f` fork per relative symlink, `cp -r` -- runs under one deadline, so the
  # default has to be generous: a legitimate 10 MB tarball with many relative
  # symlinks must not be rejected as a timeout. Test config lowers it so a
  # broken mount still fails fast.
  @default_timeout_ms 30_000

  # Tagged so a deployment misconfiguration -- no `elixir` to run the sanitizer
  # in -- can be told apart from a genuine unpack failure wherever the reason is
  # reported. `Inkfish.Uploads` logs the tagged case at `:error` with
  # `missing_elixir_log_message/0` and reports `missing_elixir_message/0` to the
  # user, and `Inkfish.Application` checks for it once at boot.
  @missing_elixir :elixir_bin_missing

  # The user-facing reason. `Inkfish.Uploads` appends it to the changeset error
  # a student sees, so it is one clear sentence that names what is missing
  # (`elixir`) and what to do about it (`:elixir_bin`, `PATH`) -- a paragraph of
  # deployment guidance does not belong in a form error.
  @missing_elixir_message "the `elixir` binary needed to unpack archives is " <>
                            "missing: set `:elixir_bin` to its full path, or " <>
                            "make `elixir` available on `PATH`"

  # The operator-facing explanation, for the log only. It names the resolution
  # order (`:elixir_bin` first, then `elixir` on `PATH`) and the consequence, so
  # the log line reads as a deployment misconfiguration rather than routine
  # noise. What it adds over `@missing_elixir_message` is the deployment-wide
  # consequence ("every upload and submission will fail until it is fixed"),
  # which belongs on the log line rather than in a form error.
  @missing_elixir_log_message "the `elixir` binary that runs the archive " <>
                                "symlink sanitizer could not be resolved: the " <>
                                "`:elixir_bin` config is unset and no `elixir` " <>
                                "executable was found on `PATH`. This is a " <>
                                "deployment misconfiguration and every upload " <>
                                "and submission will fail until it is fixed: set " <>
                                "`:elixir_bin` to the full path of the `elixir` " <>
                                "executable, or make `elixir` available on " <>
                                "`PATH`."

  @doc """
  Resolve the `elixir` executable that runs the symlink sanitizer.

  `:elixir_bin` config wins; otherwise `elixir` is looked up on `PATH`.

  Returns `{:ok, path}`, or `{:error, {:elixir_bin_missing, message}}` when
  neither resolves -- see `missing_elixir?/1` and `missing_elixir_message/0`.
  """
  def elixir_bin do
    case Application.get_env(:inkfish, :elixir_bin) ||
           System.find_executable("elixir") do
      nil -> {:error, {@missing_elixir, missing_elixir_message()}}
      path -> {:ok, path}
    end
  end

  @doc """
  Whether `reason` is the missing-`elixir` misconfiguration.
  """
  def missing_elixir?({@missing_elixir, _message}), do: true
  def missing_elixir?(_reason), do: false

  @doc """
  The user-facing reason for a missing sanitizer binary.

  One sentence: it names what is missing (`elixir`) and how to fix it
  (`:elixir_bin`, `PATH`), because it is appended to the error a user sees. The
  longer operator-facing version is `missing_elixir_log_message/0`.
  """
  def missing_elixir_message do
    @missing_elixir_message
  end

  @doc """
  The operator-facing explanation of a missing sanitizer binary.

  Log only: it spells out the consequence for the whole deployment, while the
  user gets the actionable fix from `missing_elixir_message/0`.
  """
  def missing_elixir_log_message do
    @missing_elixir_log_message
  end

  @doc """
  Safely extract an archive file.

  All of the work -- mount a capped tmpfs, unpack into it, sanitise the tree,
  copy the tree out -- happens inside a single `unshare` invocation, because
  the tmpfs only exists inside the namespace that invocation creates.

  Returns `:ok`, or `{:error, reason}` when the mount or the unpacking fails.
  A non-zero `tar` exit is fatal: extracting past the size cap leaves a
  silently truncated tree (a short file plus a zero-byte file), so a partial
  extraction must never be reported as a success. A timeout of the whole
  pipeline is reported distinctly from an unpack failure.
  """
  def safe_extract(archive, target, max_size) do
    archive = Path.expand(archive)
    target = Path.expand(target)

    with {:ok, script} <- unpack(archive, target),
         {:ok, elixir} <- elixir_bin() do
      case TempFs.run_in_one_tempfs(max_size, "bash", ["-c", script],
             env: script_env(archive, target, elixir),
             timeout_ms: timeout_ms()
           ) do
        {:ok, output} ->
          forward_warnings(output)
          :ok

        {:error, reason} ->
          {:error, extraction_error(reason)}
      end
    end
  end

  @doc """
  Remove every symlink under `base` that escapes it.
  """
  def sanitize_links!(base) do
    load_sanitize_logic()
    Inkfish.Sandbox.SanitizeLinks.sanitize_links!(base)
  end

  @doc """
  Remove `path` when it is a symlink that escapes `base`.
  """
  def sanitize_link!(path, base) do
    load_sanitize_logic()
    Inkfish.Sandbox.SanitizeLinks.sanitize_link!(path, base)
  end

  @doc """
  Choose how `archive` should be unpacked.

  Returns `{:ok, script}`, a shell script to run inside the tmpfs, or
  `{:error, reason}` when the archive kind is not supported.
  """
  def unpack(archive, _target) do
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
    #{sanitize_command()}
    cp -r "$TMPFS/." "$INKFISH_TARGET"
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
    #{sanitize_command()}
    cp -r "$TMPFS/." "$INKFISH_TARGET"
    """
  end

  defp sanitize_command do
    ~s("$INKFISH_ELIXIR" "$INKFISH_SANITIZE" "$TMPFS")
  end

  defp script_env(archive, target, elixir) do
    [
      {"INKFISH_ARCHIVE", archive},
      {"INKFISH_TARGET", target},
      {"INKFISH_ELIXIR", elixir},
      {"INKFISH_SANITIZE", priv("sanitize.exs")}
    ]
  end

  # The sanitizer runs in its own OS process (it has to: the tree only exists
  # inside the namespace), so its `Logger.warning/1` calls land on that
  # process's stdout. Re-logging them here keeps the warnings in the caller's
  # log, which is what the `capture_log` assertions in the tests rely on.
  defp forward_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.each(fn line ->
      case String.split(line, @warning_prefix, parts: 2) do
        [_, message] -> Logger.warning(String.trim_trailing(message))
        [_] -> :ok
      end
    end)
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

  # A bare script cannot load project modules, so the logic lives in its own
  # file that both this module and the script require. `Code.require_file/1` is
  # a no-op once the file has been required, so this is cheap after the first
  # call; going through `Application.app_dir/2` keeps it working from a release.
  defp load_sanitize_logic do
    Code.require_file(priv("sanitize_logic.exs"))
  end

  defp priv(name) do
    Application.app_dir(:inkfish, "priv/sandbox/#{name}")
  end
end
