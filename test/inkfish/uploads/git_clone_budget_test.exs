defmodule Inkfish.Uploads.GitCloneBudgetTest do
  use ExUnit.Case, async: false

  import Inkfish.GitFixtures

  # The saved budget is the budget for what survives the clone, and the script
  # spends it as a count of saved bytes -- not as free space on the mount, which
  # also has to cover a 4 KiB page per file. Nothing else exercises that branch:
  # without it every blob is written verbatim.
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

    # 5m of saved budget: the 6 MB blob cannot fit and must come back as a
    # `.csum` file naming its object id. The blob limit is raised so the fetch
    # downloads it -- this test is about the saved budget, not the filter.
    {out, code} =
      run_clone_script("file://#{bare}", submit_size: "5m", blob_limit: "100m")

    cleanup_stage(out)
    assert code == 0, "script failed:\n#{out}"

    assert out =~ "replaced: big.bin -> big.bin.csum"
    assert out =~ "replaced files: 1"

    # ...and the file that does fit is still written out verbatim.
    refute out =~ "replaced: small.txt"
  end

  test "keeps a blob that fits the budget", %{base: base} do
    bare = make_repo(base, "fits", &write_blob/1)

    {out, code} =
      run_clone_script("file://#{bare}", submit_size: "20m", blob_limit: "100m")

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
end
