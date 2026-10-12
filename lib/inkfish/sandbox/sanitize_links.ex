defmodule Inkfish.Sandbox.SanitizeLinks do
  @moduledoc """
  Walks an extracted tree and removes symlinks that would escape it.

  This is the production sanitizer. `Inkfish.Sandbox.Archive.safe_extract/3`
  calls it in-process, on the staging tree, *before* that tree is moved to the
  path the upload id names. It used to be run as a separate `elixir` process
  inside the mount namespace; it is a plain module function now, so a dev
  checkout and a release run the same code by construction.

  The rules:

    * an absolute link is removed even when it resolves inside the tree,
      because once the tmpfs is gone it points somewhere else entirely
    * a relative link is kept only when `readlink -f` resolves it to the
      base directory itself or something under it
    * a link whose target cannot be read or resolved is removed

  `readlink(1)` is resolved through `PATH` before it is run, for the same reason
  `Archive.canonical/1` resolves `realpath(1)`: `System.cmd/3` *raises* when the
  binary is missing, and a raise out of the walk would reach the caller of
  `Archive.safe_extract/3` as `"Erlang error: :enoent"` rather than as the
  `{:error, _}` that function promises. A missing `readlink` is treated like any
  other target that cannot be resolved -- the link is removed -- and the log
  says which of the two it was.

  `base` is passed to the escape check *raw* (not expanded): callers hand in a
  canonical, absolute, slash-free directory -- `Archive` canonicalises the
  staging directory it passes -- and `readlink -f` output is compared against
  it as a string, so a relative or slash-terminated base, or one with an
  unresolved symlinked component, would make every in-tree relative symlink
  look like an escape.

  `Logger.warning/1` (not `IO.puts/1`) is load-bearing: the warnings have to
  reach the caller's log, which is what the tests assert on.
  """

  require Logger

  def sanitize_links!(base) do
    full = Path.expand(base)

    walk(full, fn path, stat ->
      if stat.type == :symlink do
        sanitize_link!(path, base)
      end
    end)
  end

  def sanitize_link!(path, base) do
    case File.read_link(path) do
      {:ok, raw} ->
        if String.starts_with?(raw, "/") do
          # Absolute targets are unsafe even when they resolve inside the
          # current tmpfs: after the tmpfs is unmounted they point outside
          # the upload store. Only relative, in-tree links are preserved.
          Logger.warning("removing absolute link: '#{path}' => '#{raw}'")
          File.rm!(path)
        else
          sanitize_relative_link!(path, base)
        end

      _readlink_failed ->
        Logger.warning("removing invalid link: '#{path}'")
        File.rm!(path)
    end
  end

  defp sanitize_relative_link!(path, base) do
    case readlink(path) do
      {:ok, targ} ->
        if targ != base and not String.starts_with?(targ, base <> "/") do
          Logger.warning("removing unsafe link: '#{path}' => '#{targ}'")
          File.rm!(path)
        end

      {:error, reason} ->
        Logger.warning("removing invalid link: '#{path}' (#{reason})")
        File.rm!(path)
    end
  end

  # `readlink -f` on one link, with the executable resolved first: `System.cmd/3`
  # *raises* `ErlangError` (`:enoent`) when the binary is missing, so a `case` on
  # its exit status never sees that at all -- and a raise out of the walk reaches
  # the caller of `Archive.safe_extract/3` as `"Erlang error: :enoent"` instead
  # of the `{:error, _}` it promises. A missing `readlink` is not worth failing
  # the extraction over: every relative link is then removed, which is the
  # conservative direction, and the reason is carried so the log says which of
  # the two it was.
  defp readlink(path) do
    with exe when is_binary(exe) <- System.find_executable("readlink"),
         {targ, 0} <- System.cmd(exe, ["-f", path]) do
      {:ok, String.trim(targ)}
    else
      nil -> {:error, "readlink was not found on PATH"}
      {_output, status} -> {:error, "readlink exited #{status}"}
    end
  end

  defp walk(path, op) do
    case File.lstat(path, time: :posix) do
      {:ok, stat} ->
        op.(path, stat)

        if stat.type == :directory do
          walk_dir(path, op)
        end

      {:error, _} ->
        []
    end
  end

  defp walk_dir(path, op) do
    Enum.each(File.ls!(path), fn name ->
      walk(Path.join(path, name), op)
    end)
  end
end
