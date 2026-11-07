defmodule Inkfish.Uploads.GitCloneScriptTest do
  use ExUnit.Case, async: false

  import Bitwise
  import Inkfish.GitFixtures

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

    {out, code} = run_clone_script("file://#{bare}")
    assert code == 0, "script failed:\n#{out}"

    dir = result_path(out, "dir")

    assert {:ok, "../server/proto.c"} =
             File.read_link(Path.join(dir, "client/proto.c"))

    assert File.read!(Path.join(dir, ".gitignore")) == "*.beam\n"
  end

  test "keeps the executable bit git recorded", %{base: base} do
    # `git cat-file blob` writes bytes, not modes, so a checkout that just
    # copies blob content silently turns every script into a plain file.
    bare =
      make_repo(base, "execbit", fn src ->
        script = Path.join(src, "run.sh")
        File.write!(script, "#!/bin/sh\necho hi\n")
        File.chmod!(script, 0o755)
        File.write!(Path.join(src, "notes.txt"), "plain\n")
      end)

    {out, code} = run_clone_script("file://#{bare}")
    assert code == 0, "script failed:\n#{out}"

    dir = result_path(out, "dir")

    assert (File.stat!(Path.join(dir, "run.sh")).mode &&& 0o111) != 0
    assert (File.stat!(Path.join(dir, "notes.txt")).mode &&& 0o111) == 0
  end

  test "checks out the remote's default branch, not another branch", %{
    base: base
  } do
    # `git remote add` installs `+refs/heads/*`, so a bare `git fetch --depth 1
    # origin` brings down the tip of every branch, and `FETCH_HEAD`'s first line
    # is whichever ref sorts first -- not the default branch. This branch is
    # named to sort before `main` and is deliberately much bigger, which is the
    # shape of the repository that ran production out of space.
    bare =
      make_repo_with_branch(
        base,
        "branchy",
        "aaa-side-branch",
        fn src ->
          File.write!(Path.join(src, "README.md"), "main branch\n")
        end,
        fn src ->
          for i <- 1..20 do
            File.write!(
              Path.join(src, "side-#{i}.bin"),
              :crypto.strong_rand_bytes(8192)
            )
          end
        end
      )

    {out, code} = run_clone_script("file://#{bare}")
    assert code == 0, "script failed:\n#{out}"

    dir = result_path(out, "dir")

    assert out =~ "branch: main"
    assert File.read!(Path.join(dir, "README.md")) == "main branch\n"
    refute File.exists?(Path.join(dir, "side-1.bin"))
  end

  test "excludes installed dependencies and build output", %{base: base} do
    bare =
      make_repo(base, "deps", fn src ->
        File.mkdir_p!(Path.join(src, "node_modules/dep"))

        File.write!(
          Path.join(src, "node_modules/dep/index.js"),
          "module.exports = 1\n"
        )

        File.mkdir_p!(Path.join(src, "src"))
        File.write!(Path.join(src, "src/app.js"), "console.log(1)\n")
      end)

    {out, code} = run_clone_script("file://#{bare}")
    assert code == 0, "script failed:\n#{out}"

    dir = result_path(out, "dir")

    refute File.exists?(Path.join(dir, "node_modules"))
    assert File.read!(Path.join(dir, "src/app.js")) == "console.log(1)\n"
    assert out =~ "excluded by the ignore list: 1"
  end

  test "a blob the fetch filter left out becomes a .csum naming its object id",
       %{base: base} do
    # A partial clone leaves blobs out of the packfile, and the size `git
    # ls-tree -l` reports for one is not a number. The placeholder has to name
    # the object id, which is the only thing known about a blob that was never
    # fetched -- and asking git for its content would trigger a lazy fetch and
    # download exactly what the filter was told to skip.
    bare =
      make_repo(base, "partial", fn src ->
        File.write!(
          Path.join(src, "big.bin"),
          :crypto.strong_rand_bytes(200_000)
        )

        File.write!(Path.join(src, "small.txt"), "here\n")
      end)

    blob = git!(["rev-parse", "HEAD:big.bin"], cd: bare)

    {out, code} =
      run_clone_script("file://#{bare}", blob_limit: "1k", submit_size: "5m")

    assert code == 0, "script failed:\n#{out}"

    dir = result_path(out, "dir")

    refute File.exists?(Path.join(dir, "big.bin"))
    assert File.read!(Path.join(dir, "big.bin.csum")) == "#{blob}  big.bin\n"

    # The blob that *is* there is still written verbatim.
    assert File.read!(Path.join(dir, "small.txt")) == "here\n"
    assert out =~ "replaced: big.bin -> big.bin.csum"
    assert out =~ "replaced files: 1"
  end

  test "refuses a repository with more files than the saved budget allows", %{
    base: base
  } do
    # Each entry costs a 4 KiB page of the persistent tmpfs whatever its size,
    # so the entry count -- not just the byte count -- decides whether a
    # checkout can be saved. Running out of space half way through, with
    # whatever `write` failed on, is what this replaces.
    bare =
      make_repo(base, "many", fn src ->
        for i <- 1..5 do
          File.write!(Path.join(src, "file-#{i}.txt"), "x\n")
        end
      end)

    {out, code} = run_clone_script("file://#{bare}", max_files: 2)
    assert code != 0

    assert out =~ "has 5 files after the"
    assert out =~ "the limit is 2"
    assert out =~ "Raise :git_max_files"
    refute out =~ "No space left on device"
  end

  test "reports a repository with no commits", %{base: base} do
    bare = Path.join(base, "empty.git")
    git!(["init", "-q", "--bare", bare])

    {out, code} = run_clone_script("file://#{bare}")
    assert code != 0
    assert out =~ "has no commits"
  end

  test "rejects a repository with a path-traversal tree entry", %{base: base} do
    bare = make_evil_repo(base)

    {out, code} = run_clone_script("file://#{bare}")

    assert code != 0
    assert out =~ "Invalid path in repo"
  end

  test "rejects a clone URL using a disallowed protocol", %{base: base} do
    bare =
      make_repo(base, "proto", fn src ->
        File.write!(Path.join(src, "hello.txt"), "hi")
      end)

    {out, code} =
      run_clone_script("file://#{bare}", protocols: "https:http:git")

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
      System.cmd("bash", [clone_script()],
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
