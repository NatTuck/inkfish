defmodule Inkfish.Sandbox.ArchiveTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Inkfish.Sandbox.Archive

  setup do
    base =
      Path.join(
        System.tmp_dir!(),
        "archive_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)

    {:ok, base: base}
  end

  defp tar!(archive, dir, args) do
    {_, 0} = System.cmd("tar", ["-czf", archive, "-C", dir] ++ args)
    archive
  end

  test "safe_extract does not write through an escaping symlink", %{base: base} do
    outside = Path.join(base, "outside")
    stage = Path.join(base, "stage")
    target = Path.join(base, "target")
    File.mkdir_p!(Path.join(stage, "real"))
    File.mkdir_p!(outside)
    File.mkdir_p!(target)

    File.write!(Path.join(outside, "original.txt"), "secret")
    File.ln_s!(outside, Path.join(stage, "evil"))
    File.write!(Path.join(stage, "real/pwned"), "pwned")

    # Archive a symlink "evil -> <outside>", then a file whose stored path
    # goes through that symlink. GNU tar refuses to follow it.
    archive =
      tar!(Path.join(base, "evil.tar.gz"), stage, [
        "--transform=s,^real/,evil/,",
        "evil",
        "real/pwned"
      ])

    Archive.safe_extract(archive, target, "10M")

    refute File.exists?(Path.join(outside, "pwned"))
    assert File.read!(Path.join(outside, "original.txt")) == "secret"
  end

  test "safe_extract removes an escaping symlink", %{base: base} do
    stage = Path.join(base, "stage")
    target = Path.join(base, "target")
    File.mkdir_p!(stage)
    File.mkdir_p!(target)

    File.ln_s!("/etc/passwd", Path.join(stage, "leak"))
    archive = tar!(Path.join(base, "leak.tar.gz"), stage, ["leak"])

    log =
      capture_log(fn ->
        assert :ok = Archive.safe_extract(archive, target, "10M")
      end)

    assert log =~ "removing absolute link"
    assert {:error, :enoent} = File.lstat(Path.join(target, "leak"))
  end

  test "safe_extract preserves an in-tree relative symlink", %{base: base} do
    stage = Path.join(base, "stage")
    target = Path.join(base, "target")
    File.mkdir_p!(Path.join(stage, "client"))
    File.mkdir_p!(Path.join(stage, "server"))
    File.mkdir_p!(target)

    File.write!(Path.join(stage, "server/proto.c"), "int main;")
    File.ln_s!("../server/proto.c", Path.join(stage, "client/proto.c"))
    archive = tar!(Path.join(base, "links.tar.gz"), stage, ["client", "server"])

    log =
      capture_log(fn ->
        assert :ok = Archive.safe_extract(archive, target, "10M")
      end)

    refute log =~ "removing"

    assert {:ok, "../server/proto.c"} =
             File.read_link(Path.join(target, "client/proto.c"))
  end

  test "safe_extract preserves dotfiles", %{base: base} do
    stage = Path.join(base, "stage")
    target = Path.join(base, "target")
    File.mkdir_p!(stage)
    File.mkdir_p!(target)

    File.write!(Path.join(stage, ".gitignore"), "*.beam\n")
    archive = tar!(Path.join(base, "dots.tar.gz"), stage, [".gitignore"])

    log =
      capture_log(fn ->
        assert :ok = Archive.safe_extract(archive, target, "10M")
      end)

    refute log =~ "removing"
    assert File.read!(Path.join(target, ".gitignore")) == "*.beam\n"
  end

  describe "sanitize_link!/2" do
    test "removes an absolute link even when it resolves in-tree", %{base: base} do
      File.write!(Path.join(base, "target.txt"), "x")
      link = Path.join(base, "link")
      File.ln_s!(Path.join(base, "target.txt"), link)

      log = capture_log(fn -> Archive.sanitize_link!(link, base) end)

      assert log =~ "removing absolute link"
      assert {:error, :enoent} = File.lstat(link)
    end

    test "removes a link escaping to a numeric-prefix sibling", %{base: base} do
      inside = Path.join(base, "123")
      sibling = Path.join(base, "1234")
      File.mkdir_p!(Path.join(inside, "sub"))
      File.mkdir_p!(sibling)
      File.write!(Path.join(sibling, "evil"), "x")

      link = Path.join(inside, "sub/link")
      File.ln_s!("../../1234/evil", link)

      log = capture_log(fn -> Archive.sanitize_link!(link, inside) end)

      assert log =~ "removing unsafe link"
      assert {:error, :enoent} = File.lstat(link)
    end

    test "keeps a relative in-tree link", %{base: base} do
      File.write!(Path.join(base, "target.txt"), "x")
      link = Path.join(base, "link")
      File.ln_s!("target.txt", link)

      log = capture_log(fn -> Archive.sanitize_link!(link, base) end)

      refute log =~ "removing"
      assert {:ok, "target.txt"} = File.read_link(link)
    end
  end
end
