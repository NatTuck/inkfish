# The single source of truth for archive symlink sanitisation.
#
# This file is loaded twice, from two different places:
#
#   * `Inkfish.Sandbox.Archive` requires it and delegates to it, so the
#     in-process unit tests exercise exactly the code that runs in production.
#   * `priv/sandbox/sanitize.exs` runs it inside the tmpfs namespace, where the
#     extracted tree actually exists.
#
# It must stay a bare module definition: requiring it has to be free of side
# effects. The argv dispatch lives in `sanitize.exs`, because a dispatch at the
# bottom of this file would fire when Archive requires it.
#
# `Logger.warning/1` (not `IO.puts/1`) is load-bearing: the direct
# `Archive.sanitize_link!/2` tests assert on `capture_log` output.

defmodule Inkfish.Sandbox.SanitizeLinks do
  @moduledoc """
  Walks an extracted tree and removes symlinks that would escape it.

  The rules:

    * an absolute link is removed even when it resolves inside the tree,
      because once the tmpfs is gone it points somewhere else entirely
    * a relative link is kept only when `readlink -f` resolves it to the
      base directory itself or something under it
    * a link whose target cannot be read or resolved is removed

  `base` is passed to the escape check *raw* (not expanded): callers hand in
  the mount path, which is absolute and has no trailing slash.
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

  # A bare script cannot load project modules, so the walk lives here rather
  # than in a separate `Inkfish.Sandbox.Traverse`.
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
