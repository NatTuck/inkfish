defmodule Inkfish.Sandbox.ArchiveTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Inkfish.Sandbox.Archive
  alias Inkfish.Sandbox.TempFs

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

  # `data/twenty.tar.gz` holds a single 20,971,520 byte file, so it cannot be
  # extracted under any cap smaller than that.
  defp twenty_tarball do
    Path.expand("../../scripts/data/twenty.tar.gz", __DIR__)
  end

  # Run `fun` with no `elixir` resolvable: no `:elixir_bin` config, and a `PATH`
  # pointing at an existing but empty directory. `PATH` and the application env
  # are VM-global, so both are restored before `fun` returns -- and again in
  # `on_exit` as a safety net -- to leave the rest of the suite untouched.
  defp without_elixir(base, fun) do
    old_path = System.get_env("PATH")
    old_bin = Application.get_env(:inkfish, :elixir_bin)

    restore = fn ->
      if old_path do
        System.put_env("PATH", old_path)
      else
        System.delete_env("PATH")
      end

      if old_bin do
        Application.put_env(:inkfish, :elixir_bin, old_bin)
      else
        Application.delete_env(:inkfish, :elixir_bin)
      end
    end

    on_exit(restore)

    empty_bin = Path.join(base, "empty-bin")
    File.mkdir_p!(empty_bin)
    Application.delete_env(:inkfish, :elixir_bin)
    System.put_env("PATH", empty_bin)

    try do
      fun.()
    after
      restore.()
    end
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

  describe "the size cap" do
    # A suite that only ever uses one cap size cannot tell a transposed or
    # ignored size from a correct one, so check two, and check each one against
    # what the kernel itself reports: a real tmpfs, mounted at exactly the
    # requested size, where a write that fits succeeds and one that does not is
    # refused with ENOSPC.
    test "is enforced at the requested size" do
      for {size, fits_mb, over_mb} <- [{"10M", 8, 12}, {"3M", 2, 4}] do
        assert {:ok, out} =
                 TempFs.run_in_one_tempfs(size, "bash", [
                   "-c",
                   ~s(findmnt -no FSTYPE,SIZE "$TMPFS")
                 ])

        assert String.split(out, [" ", "\n"], trim: true) == ["tmpfs", size]

        assert {:ok, _out} =
                 TempFs.run_in_one_tempfs(size, "bash", [
                   "-c",
                   ~s(dd if=/dev/zero of="$TMPFS/fits" bs=1M count=#{fits_mb})
                 ])

        assert {:error, msg} =
                 TempFs.run_in_one_tempfs(size, "bash", [
                   "-c",
                   ~s(dd if=/dev/zero of="$TMPFS/over" bs=1M count=#{over_mb})
                 ])

        assert msg =~ "No space left on device"
      end
    end

    test "a cap hit is a failure, not a truncated tree", %{base: base} do
      target = Path.join(base, "target")
      File.mkdir_p!(target)

      assert File.exists?(twenty_tarball())

      # 20M of tar into a 10M tmpfs: `tar` stops with ENOSPC part way through
      # and leaves a truncated file plus a zero byte one behind. That partial
      # extraction must never be reported as a success, and nothing may be
      # copied out to the target.
      assert {:error, msg} =
               Archive.safe_extract(twenty_tarball(), target, "10M")

      assert msg =~ "exited 2"

      assert File.ls!(target) == []
    end
  end

  # A missing `elixir` binary is a deployment misconfiguration, not a bad
  # archive: it has to be detectable, and it has to say which binary is missing
  # rather than looking like an ordinary unpack failure.
  describe "a missing elixir binary" do
    test "is reported by elixir_bin/0", %{base: base} do
      result = without_elixir(base, fn -> Archive.elixir_bin() end)

      assert {:error, reason} = result
      assert Archive.missing_elixir?(reason)

      assert {:elixir_bin_missing, message} = reason
      assert message =~ "elixir"
      assert message =~ ":elixir_bin"
      assert message =~ "PATH"
    end

    test "carries a single-sentence reason, not a paragraph", %{base: base} do
      # This reason is appended to the error a user sees, so it has to stay one
      # sentence: the paragraph-length deployment guidance is log only. Keep it
      # specific while it is short -- it still has to name the missing binary
      # and both ways to resolve it.
      assert {:error, {:elixir_bin_missing, message}} =
               without_elixir(base, fn -> Archive.elixir_bin() end)

      refute String.contains?(message, "\n")
      assert String.length(message) < 200

      assert message =~ "elixir"
      assert message =~ ":elixir_bin"
      assert message =~ "PATH"

      assert String.length(Archive.missing_elixir_log_message()) >
               String.length(message)
    end

    test "is surfaced by safe_extract/3 instead of a generic failure", %{
      base: base
    } do
      stage = Path.join(base, "stage")
      target = Path.join(base, "target")
      File.mkdir_p!(stage)
      File.mkdir_p!(target)
      File.write!(Path.join(stage, "hello.txt"), "hi")
      archive = tar!(Path.join(base, "plain.tar.gz"), stage, ["hello.txt"])

      result =
        without_elixir(base, fn ->
          Archive.safe_extract(archive, target, "10M")
        end)

      assert {:error, reason} = result
      assert Archive.missing_elixir?(reason)
      assert File.ls!(target) == []
    end
  end

  describe "the failure path" do
    test "reports a bad size in bounded time, naming it" do
      # "1X" is not a tmpfs size, so it is refused in Elixir, before a port is
      # opened and long before `mount(8)` would run, with a diagnostic that
      # names the size. (The kernel's own refusal is not reachable through a
      # size any more: `mount(8)` reports every EINVAL from `mount(2)` as one
      # generic sentence that never mentions the size, which is why the size is
      # checked first, where we can still name it.)
      {elapsed_us, result} =
        :timer.tc(fn ->
          TempFs.run_in_one_tempfs("1X", "bash", ["-c", "echo hi"])
        end)

      assert {:error, msg} = result
      assert msg =~ "invalid tmpfs size"
      assert elapsed_us < 5_000_000
    end

    test "reports a missing helper in bounded time" do
      {elapsed_us, result} =
        :timer.tc(fn ->
          TempFs.run_in_one_tempfs("10M", "bash", ["-c", "echo hi"],
            bin: "inkfish-no-such-unshare"
          )
        end)

      assert {:error, msg} = result
      assert msg =~ "not found"
      assert elapsed_us < 5_000_000
    end

    test "safe_extract surfaces a bad size instead of an empty tree", %{
      base: base
    } do
      archive = Path.expand("../../scripts/data/helloc.tar.gz", __DIR__)
      target = Path.join(base, "target")
      File.mkdir_p!(target)

      # "1X" is not a tmpfs size, so it is refused in Elixir, naming it, before
      # anything is spawned. Either way the failure has to reach the caller --
      # an empty tree is not a success.
      assert {:error, msg} = Archive.safe_extract(archive, target, "1X")
      assert msg =~ "invalid tmpfs size"

      assert File.ls!(target) == []
    end
  end
end
