defmodule Inkfish.Uploads.GitCloneBudgetTest do
  use ExUnit.Case, async: false

  import Inkfish.GitFixtures

  alias Inkfish.Sandbox.TempFs

  @script Path.join(:code.priv_dir(:inkfish), "scripts/upload_git_clone.sh")

  # The persistent tmpfs is the budget for what survives the clone, and the
  # script keeps 512 KB of it back for directory entries and the trimmed git
  # metadata. Nothing else exercises that branch: without a capped mount the
  # `df` reading is always huge and every blob is written verbatim.
  @blob_bytes 6 * 1024 * 1024

  setup do
    assert System.find_executable("bash")
    assert System.find_executable("git")
    assert System.find_executable("unshare")

    base =
      Path.join(
        System.tmp_dir!(),
        "git_clone_budget_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    {:ok, base: base}
  end

  test "replaces a blob larger than the budget with a checksum", %{base: base} do
    bare = make_repo(base, "big", &write_blob/1)

    # 5m of persistent tmpfs is 5120 KB, so the budget is 4608 KB: the 6 MB
    # blob cannot fit and must come back as a `.csum` file naming its hash.
    {out, code} = run_script("file://#{bare}", "5m")
    cleanup_stage(out)
    assert code == 0, "script failed:\n#{out}"

    assert out =~ "replaced: big.bin -> big.bin.csum"
    assert out =~ "replaced files: 1"

    # ...and the file that does fit is still written out verbatim.
    refute out =~ "replaced: small.txt"
  end

  test "keeps a blob that fits the budget", %{base: base} do
    bare = make_repo(base, "fits", &write_blob/1)

    {out, code} = run_script("file://#{bare}", "20m")
    cleanup_stage(out)
    assert code == 0, "script failed:\n#{out}"

    assert out =~ "replaced files: 0"
    refute out =~ ".csum"
  end

  # The script copies its results into a staging directory and only its caller
  # (`Inkfish.Uploads.Git.create_upload/3`) removes it. This test runs the
  # script directly, so it has to reclaim that directory itself -- the 6 MB
  # blob run stages ~13 MB, so the leak is real.
  defp cleanup_stage(out) do
    case Regex.run(~r/^dir: (.+)$/m, out) do
      [_, dir] ->
        stage = Path.dirname(String.trim(dir))
        on_exit(fn -> File.rm_rf!(stage) end)

      _ ->
        :ok
    end
  end

  defp write_blob(src) do
    File.write!(
      Path.join(src, "big.bin"),
      :crypto.strong_rand_bytes(@blob_bytes)
    )

    File.write!(Path.join(src, "small.txt"), "fits\n")
  end

  defp run_script(repo, submit_size) do
    # The persistent tmpfs has to be a real capped mount for the `df` reading to
    # mean anything, so the script is run the way production runs it: through
    # `Inkfish.Sandbox.TempFs.unshare_argv/3`, which mounts CLONE_TMP and
    # PERSIST_TMP (this `submit_size` is what caps the latter) and exports their
    # paths. Only the runner differs from production -- a test wants the output
    # and exit status back.
    {:ok, [unshare | args]} =
      TempFs.unshare_argv(
        [{"CLONE_TMP", "100m"}, {"PERSIST_TMP", submit_size}],
        "bash",
        [@script]
      )

    System.cmd(unshare, args,
      env: [
        {"REPO", repo},
        {"CLONE_SIZE", "100m"},
        {"SUBMIT_SIZE", submit_size},
        {"GIT_ALLOW_PROTOCOL", "https:http:git:file"},
        {"COOKIE", "testcookie"}
      ],
      stderr_to_stdout: true
    )
  end
end
