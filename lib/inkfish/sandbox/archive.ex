defmodule Inkfish.Sandbox.Archive do
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
        {_, 0} = System.cmd("bash", ["-c", ~s(cp -r "#{tdir}"/* "#{target}")])
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
    case System.cmd("readlink", ["-f", path]) do
      {targ, 0} ->
        targ = String.trim(targ)
        pref = String.slice(targ, 0, String.length(base))

        if pref != base do
          IO.puts("removing unsafe link: '#{path}' => '#{targ}'")
          File.rm!(path)
        end

      _readlink_failed ->
        IO.puts("removing invalid link: '#{path}'")
        File.rm!(path)
    end
  end

  def unpack(archive, target) do
    cond do
      Regex.match?(~r/\.tar\.(gz|xz|bz2)$/, archive) ->
        untar(archive, target)

      Regex.match?(~r/\.zip$/, archive) ->
        raise "TODO: zip archives"

      true ->
        name = Path.basename(archive)
        File.copy!(archive, Path.join(target, name))
        :ok
    end
  end

  def untar(archive, target) do
    File.mkdir_p!(target)

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
