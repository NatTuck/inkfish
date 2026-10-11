defmodule Inkfish.Uploads.GitCloneScriptTest do
  use ExUnit.Case, async: false

  import Inkfish.GitFixtures

  alias Inkfish.Sandbox.TempFs

  @script Path.join(:code.priv_dir(:inkfish), "scripts/upload_git_clone.sh")

  setup do
    assert System.find_executable("bash")
    assert System.find_executable("git")
    assert System.find_executable("unshare")

    base =
      Path.join(
        System.tmp_dir!(),
        "git_clone_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    {:ok, base: base}
  end

  test "materializes safe in-tree symlinks and dotfiles", %{base: base} do
    bare =
      make_repo(base, "good", fn src ->
        File.mkdir_p!(Path.join(src, "server"))
        File.mkdir_p!(Path.join(src, "client"))
        File.write!(Path.join(src, "server/proto.c"), "int main;")
        File.ln_s!("../server/proto.c", Path.join(src, "client/proto.c"))
        File.write!(Path.join(src, ".gitignore"), "*.beam\n")
      end)

    {out, code} = run_script("file://#{bare}", "https:http:git:file")
    assert code == 0, "script failed:\n#{out}"

    dir = result_path(out, "dir")

    assert {:ok, "../server/proto.c"} =
             File.read_link(Path.join(dir, "client/proto.c"))

    assert File.read!(Path.join(dir, ".gitignore")) == "*.beam\n"
  end

  test "rejects a repository with a path-traversal tree entry", %{base: base} do
    bare = make_evil_repo(base)

    {out, code} = run_script("file://#{bare}", "https:http:git:file")

    assert code != 0
    assert out =~ "Invalid path in repo"
  end

  test "rejects a clone URL using a disallowed protocol", %{base: base} do
    bare =
      make_repo(base, "proto", fn src ->
        File.write!(Path.join(src, "hello.txt"), "hi")
      end)

    {out, code} = run_script("file://#{bare}", "https:http:git")

    assert code != 0
    assert out =~ "transport 'file' not allowed"
  end

  test "refuses to run outside the sandbox, and says so" do
    # Production always runs this script through `Inkfish.Sandbox.TempFs`, whose
    # preamble is what creates CLONE_TMP/PERSIST_TMP. Run bare -- as this test
    # does, with no mounts -- the two assertions at the top of the script fire,
    # so the script says it was run without the sandbox rather than failing
    # later with a confusing EROFS. (`REPO` is a path that does not exist, so a
    # version of the script that got past the assertions still could not clone
    # anything.)
    {out, code} =
      System.cmd("bash", [@script],
        env: [
          {"REPO", "file:///inkfish-no-such-repo.git"},
          {"CLONE_SIZE", "100m"},
          {"SUBMIT_SIZE", "5m"},
          {"GIT_ALLOW_PROTOCOL", "https:http:git:file"},
          {"COOKIE", "testcookie"}
        ],
        stderr_to_stdout: true
      )

    refute code == 0
    assert out =~ "CLONE_TMP is not set"
    assert out =~ "must run inside the tempfs sandbox"
  end

  defp run_script(repo, protocols) do
    # Run the script exactly the way production does: `Git.start_clone/1` builds
    # this same argv -- the same two mounts at the same sizes, through the same
    # `Inkfish.Sandbox.TempFs` primitive -- and hands it to Ittys. Only the
    # runner differs here, because a test wants the output and exit status back.
    {:ok, [unshare | args]} =
      TempFs.unshare_argv(
        [{"CLONE_TMP", "100m"}, {"PERSIST_TMP", "5m"}],
        "bash",
        [@script]
      )

    System.cmd(unshare, args,
      env: [
        {"REPO", repo},
        {"CLONE_SIZE", "100m"},
        {"SUBMIT_SIZE", "5m"},
        {"GIT_ALLOW_PROTOCOL", protocols},
        {"COOKIE", "testcookie"}
      ],
      stderr_to_stdout: true
    )
  end

  defp result_path(out, key) do
    case Regex.run(~r/^#{key}: (.+)$/m, out) do
      [_, path] -> String.trim(path)
      _ -> flunk("no #{key}: line in output:\n#{out}")
    end
  end

  defp make_evil_repo(base) do
    bare = Path.join(base, "evil.git")
    File.mkdir_p!(bare)
    git!(["init", "-q", "--bare"], cd: bare)

    payload = Path.join(base, "payload.txt")
    File.write!(payload, "pwned")
    blob = git!(["hash-object", "-w", payload], cd: bare)

    {tree, 0} =
      System.cmd(
        "bash",
        ["-c", "printf '100644 blob #{blob}\\t..\\n' | git mktree"],
        cd: bare
      )

    tree = String.trim(tree)

    commit =
      git!(["commit-tree", tree, "-m", "evil"],
        cd: bare,
        env: [
          {"GIT_AUTHOR_NAME", "Test"},
          {"GIT_AUTHOR_EMAIL", "test@example.com"},
          {"GIT_COMMITTER_NAME", "Test"},
          {"GIT_COMMITTER_EMAIL", "test@example.com"}
        ]
      )

    git!(["update-ref", "refs/heads/master", commit], cd: bare)
    git!(["symbolic-ref", "HEAD", "refs/heads/master"], cd: bare)
    bare
  end
end
