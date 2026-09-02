defmodule Inkfish.Uploads.GitTest do
  use Inkfish.DataCase, async: true

  alias Inkfish.Uploads.Git

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
