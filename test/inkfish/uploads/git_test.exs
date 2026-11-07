defmodule Inkfish.Uploads.GitTest do
  use Inkfish.DataCase, async: true

  import ExUnit.CaptureLog
  import Inkfish.Factory

  alias Inkfish.Uploads.Git
  alias Inkfish.Uploads.Upload

  describe "parse_results/1" do
    test "parses key: value lines into a map" do
      text = """
      Git checkout succeeded.

      cookiemarker
      dir: /tmp/tmptmpfs/1/repo
      tar: /tmp/tmptmpfs/2/repo.tar.gz
      """

      assert {:ok, results} = Git.parse_results(text)
      assert results["dir"] == "/tmp/tmptmpfs/1/repo"
      assert results["tar"] == "/tmp/tmptmpfs/2/repo.tar.gz"
    end

    test "ignores lines that are not key:value pairs" do
      text = """
      Cloning git repo...
      fatal: unable to checkout working tree
      dir: /tmp/tmptmpfs/1/repo
      tar: /tmp/tmptmpfs/2/repo.tar.gz
      """

      assert {:ok, results} = Git.parse_results(text)
      assert results["dir"] == "/tmp/tmptmpfs/1/repo"
    end

    test "returns an error when dir/tar are missing (failed clone)" do
      text = """
      Cloning git repo...
      fatal: unable to checkout working tree
      """

      assert {:error, :incomplete_results} = Git.parse_results(text)
    end

    test "returns an error on empty output" do
      assert {:error, :incomplete_results} = Git.parse_results("")
    end
  end

  describe "create_upload/3" do
    test "returns an error when dir/tar are missing" do
      assert :error = Git.create_upload(%{"dir" => "/tmp/nope"}, "sub", 1)
    end

    test "moves a staged checkout into place instead of copying it" do
      # The staging directory is created on the uploads filesystem so the
      # results can be renamed into their final home: the checkout the script
      # staged is already the tree we want, and copying it again doubles both
      # the time and the disk the upload takes.
      user = insert(:user)

      stage =
        Path.join(
          Upload.upload_base(),
          "inkfish-clone-#{Base.encode16(:crypto.strong_rand_bytes(6))}"
        )

      dir = Path.join(stage, "repo")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "hello.txt"), "hi\n")
      tar = Path.join(stage, "repo.tar.gz")
      File.write!(tar, "tarball")

      on_exit(fn -> File.rm_rf!(stage) end)

      assert {:ok, upload} =
               Git.create_upload(
                 %{"dir" => dir, "tar" => tar, "stage" => stage},
                 "sub",
                 user.id
               )

      on_exit(fn -> File.rm_rf!(Upload.upload_dir(upload)) end)

      assert File.read!(Path.join(Upload.unpacked_path(upload), "hello.txt")) ==
               "hi\n"

      assert File.read!(Upload.upload_path(upload)) == "tarball"

      # The whole staging directory is reclaimed, not just left behind.
      refute File.exists?(stage)
    end

    test "removes a symlink that escapes the staged checkout, and says so" do
      # The clone script decides containment per entry while it writes the tree,
      # which a link written later can defeat. The unpacked tree is served by
      # `/uploads/:id/_meta/unpacked/*path`, which follows symlinks, so the
      # finished tree is checked again here -- the same `SanitizeLinks` pass the
      # archive path runs.
      user = insert(:user)

      stage =
        Path.join(
          Upload.upload_base(),
          "inkfish-clone-#{Base.encode16(:crypto.strong_rand_bytes(6))}"
        )

      dir = Path.join(stage, "repo")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "hello.txt"), "hi\n")
      File.ln_s!("../../../../etc", Path.join(dir, "escape"))
      tar = Path.join(stage, "repo.tar.gz")
      File.write!(tar, "tarball")

      on_exit(fn -> File.rm_rf!(stage) end)

      log =
        capture_log(fn ->
          assert {:ok, upload} =
                   Git.create_upload(
                     %{"dir" => dir, "tar" => tar, "stage" => stage},
                     "sub",
                     user.id
                   )

          on_exit(fn -> File.rm_rf!(Upload.upload_dir(upload)) end)

          unpacked = Upload.unpacked_path(upload)
          assert File.read!(Path.join(unpacked, "hello.txt")) == "hi\n"
          assert {:error, :enoent} = File.lstat(Path.join(unpacked, "escape"))
        end)

      assert log =~ "removing unsafe link"
      assert log =~ "escape"
    end

    test "copies rather than moves a checkout from outside the staging directory" do
      # A move is destructive, so a `dir` the script did not report inside the
      # staging directory it was given is copied instead. The tests hand in
      # their own directories, which is exactly that case.
      user = insert(:user)

      stage =
        Path.join(
          Upload.upload_base(),
          "inkfish-clone-#{Base.encode16(:crypto.strong_rand_bytes(6))}"
        )

      File.mkdir_p!(stage)
      tar = Path.join(stage, "repo.tar.gz")
      File.write!(tar, "tarball")

      elsewhere =
        Path.join(
          System.tmp_dir!(),
          "git_test_outside_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(elsewhere)
      File.write!(Path.join(elsewhere, "hello.txt"), "hi\n")

      on_exit(fn ->
        File.rm_rf!(stage)
        File.rm_rf!(elsewhere)
      end)

      assert {:ok, upload} =
               Git.create_upload(
                 %{"dir" => elsewhere, "tar" => tar, "stage" => stage},
                 "sub",
                 user.id
               )

      on_exit(fn -> File.rm_rf!(Upload.upload_dir(upload)) end)

      assert File.read!(Path.join(Upload.unpacked_path(upload), "hello.txt")) ==
               "hi\n"

      # The source is still where it was: it was copied, not moved.
      assert File.exists?(Path.join(elsewhere, "hello.txt"))
    end

    test "returns an error when the cloned tarball has gone" do
      user = insert(:user)
      base = git_test_dir()
      dir = Path.join(base, "repo")
      File.mkdir_p!(dir)

      assert {:error, message} =
               Git.create_upload(
                 %{"dir" => dir, "tar" => Path.join(base, "gone.tar.gz")},
                 "sub",
                 user.id
               )

      assert message =~ "could not read the cloned tarball"
      assert message =~ "enoent"
    end

    test "returns an error naming the reason when the upload row is rejected" do
      base = git_test_dir()

      tar = Path.join(base, "repo.tar.gz")
      File.write!(tar, "not really a tarball")
      dir = Path.join(base, "repo")
      File.mkdir_p!(dir)

      assert {:error, message} =
               Git.create_upload(%{"dir" => dir, "tar" => tar}, "bogus_kind", 1)

      assert message =~ "could not record upload"
      assert message =~ "invalid upload kind: bogus_kind"
    end

    test "returns an error naming the reason when the tarball copy fails" do
      user = insert(:user)
      base = git_test_dir()

      # A directory where the tarball should be makes `File.cp/2` fail with
      # `:eisdir`; the size lookup uses `File.stat!/1`, which still succeeds.
      tar = Path.join(base, "repo.tar.gz")
      File.mkdir_p!(tar)
      dir = Path.join(base, "repo")
      File.mkdir_p!(dir)

      assert {:error, message} =
               Git.create_upload(%{"dir" => dir, "tar" => tar}, "sub", user.id)

      assert message =~ "could not copy upload tarball"
      assert message =~ "eisdir"

      # The insert (and `upload_path/1`, which makes the destination directory)
      # ran before the copy failed, so reclaim the directory it created.
      upload = Repo.one(from u in Upload, where: u.user_id == ^user.id)
      if upload, do: File.rm_rf(Upload.upload_dir(upload))
    end
  end

  describe "repo_info/1" do
    test "reads url and commit from a git checkout" do
      dir =
        setup_git_checkout(
          "https://github.com/owner/repo.git",
          "5bea7bb1a138168b0c50829852cd1b6252627abb"
        )

      assert %{
               url: "https://github.com/owner/repo.git",
               commit: "5bea7bb1a138168b0c50829852cd1b6252627abb"
             } =
               Git.repo_info(dir)
    end

    test "falls back to FETCH_HEAD when shallow is missing" do
      dir =
        setup_git_checkout(
          "https://github.com/owner/repo.git",
          nil,
          "5bea7bb1a138168b0c50829852cd1b6252627abb"
        )

      assert %{commit: "5bea7bb1a138168b0c50829852cd1b6252627abb"} =
               Git.repo_info(dir)
    end

    test "returns nil for a checkout without .git metadata" do
      dir = setup_git_checkout(nil)

      assert Git.repo_info(dir) == nil
    end

    test "reports the host the URL actually points at" do
      # `https://github.com@evil.example/x` is a truthful URL that reads as
      # github.com at a glance, and the URL is what a grader uses to decide
      # whether the starter repository was cloned.
      dir =
        setup_git_checkout(
          "https://github.com@evil.example/x",
          "5bea7bb1a138168b0c50829852cd1b6252627abb"
        )

      assert %{url: "https://github.com@evil.example/x", host: "evil.example"} =
               Git.repo_info(dir)
    end
  end

  defp git_test_dir do
    base =
      Path.join(
        System.tmp_dir!(),
        "git_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)
    base
  end

  defp setup_git_checkout(
         url,
         commit \\ "5bea7bb1a138168b0c50829852cd1b6252627abb",
         fetch_commit \\ nil
       ) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "git_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    if url do
      git = Path.join(dir, ".git")
      File.mkdir_p!(git)

      File.write!(Path.join(git, "config"), """
      [core]
      \trepositoryformatversion = 0
      [remote "origin"]
      \turl = #{url}
      \tfetch = +refs/heads/*:refs/remotes/origin/*
      """)

      if commit do
        File.write!(Path.join(git, "shallow"), commit <> "\n")
      end

      File.write!(
        Path.join(git, "FETCH_HEAD"),
        "#{fetch_commit || commit}\t\tbranch 'master' of #{url}\n"
      )
    end

    dir
  end
end
