defmodule Inkfish.GitFixtures do
  def make_repo(base, name, setup \\ fn _ -> :ok end) do
    src = Path.join(base, name)
    File.mkdir_p!(src)
    git!(["init", "-q"], cd: src)
    git!(["config", "user.email", "test@example.com"], cd: src)
    git!(["config", "user.name", "Test"], cd: src)
    setup.(src)
    git!(["add", "-A"], cd: src)
    git!(["commit", "-qm", "init"], cd: src)

    bare = Path.join(base, "#{name}.git")
    git!(["clone", "-q", "--bare", src, bare])
    bare
  end

  def git!(args, opts \\ []) do
    {out, 0} = System.cmd("git", args, opts)
    String.trim(out)
  end
end
