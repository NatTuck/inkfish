defmodule Inkfish.Sandbox.Archive do
  require Logger

  alias Inkfish.Sandbox
  alias Sandbox.TempFs
  alias Sandbox.Traverse
  alias Sandbox.Shell

  @doc """
  Safely extract an archive file.
  """
  def safe_extract(archive, target, max_size) do
    archive = Path.expand(archive)
    target = Path.expand(target)
    {:ok, tdir} = TempFs.make_tempfs(max_size)

    case unpack(archive, tdir) do
      :ok ->
        sanitize_links!(tdir)

        # Copying `tdir/.` includes dotfiles, unlike a `tdir/*` glob. With
        # -r, cp copies symlinks as symlinks (rather than following them)
        # and does not preserve setuid/setgid bits. `target` is created by
        # the caller.
        {_, 0} = System.cmd("bash", ["-c", ~s(cp -r "#{tdir}/." "#{target}")])
        :ok

      {:error, text} ->
        {:error, text}
    end
  end

  def sanitize_links!(base) do
    full = Path.expand(base)

    Traverse.walk(full, fn path, stat ->
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

  def unpack(archive, target) do
    cond do
      Regex.match?(~r/\.tar\.(gz|xz|bz2)$/, archive) ->
        untar(archive, target)

      Regex.match?(~r/\.zip$/, archive) ->
        {:error, "zip archives are not supported"}

      true ->
        name = Path.basename(archive)
        File.copy!(archive, Path.join(target, name))
        :ok
    end
  end

  def untar(archive, target) do
    File.mkdir_p!(target)

    # Do not add -P/--absolute-names or -h/--dereference here: tar's default
    # refusal to follow links that escape the working directory is what keeps
    # a crafted archive from writing outside the tmpfs.
    Shell.run_script("""
    cd "#{target}" && tar xvf "#{archive}"
    """)
  end

  def tar(src, archive) do
    dir = Path.dirname(src)
    File.mkdir_p!(Path.dirname(archive))

    Shell.run_script("""
    cd "#{dir}" && tar czvf "#{archive}"
    """)
  end
end
