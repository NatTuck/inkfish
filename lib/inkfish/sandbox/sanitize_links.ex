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
    case System.cmd("readlink", ["-f", path]) do
      {targ, 0} ->
        targ = String.trim(targ)

        if targ != base and not String.starts_with?(targ, base <> "/") do
          Logger.warning("removing unsafe link: '#{path}' => '#{targ}'")
          File.rm!(path)
        end

      _readlink_failed ->
        Logger.warning("removing invalid link: '#{path}'")
        File.rm!(path)
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
