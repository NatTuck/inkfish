defmodule Inkfish.Sandbox.ArchiveTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Inkfish.Sandbox.Archive
  alias Inkfish.Sandbox.TempFs
  alias Inkfish.Uploads.Upload

  setup do
    # Under the upload base, not the temp dir. `safe_extract/3` extracts into a
    # staging directory under the upload base and then *renames* it into place,
    # so the target has to be on the same filesystem -- which is what the real
    # caller guarantees, since `Upload.unpacked_path/1` is under the upload base
    # too. A target anywhere else is not a configuration this code supports.
    base =
      Path.join(
        Upload.upload_base(),
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

  # Every staged copy of `marker` still under the staging root. A success moves
  # the staged tree into place, so the marker must not be under it any more;
  # only a tree that never made it to its target is still there.
  defp staged_markers(marker) do
    Path.wildcard(Path.join(Archive.staging_root(), "*/#{marker}"))
  end

  # A failure leaves the staging directory behind on purpose (see
  # `move_into_place/2`), so a test that provokes one has to remove it itself --
  # on exit, so a failed assertion does not leave the tree there either.
  defp cleanup_staged(marker) do
    for staged_marker <- staged_markers(marker) do
      File.rm_rf!(Path.dirname(staged_marker))
    end
  end

  # Poll `paths` as fast as the scheduler allows until told to stop, then answer
  # whether any of them was ever there. `File.lstat/1`, not `File.exists?/1`:
  # these are symlinks that point outside the tree, so a dangling one is
  # exactly the thing that must never appear at the final path.
  defp watch(paths, seen?) do
    seen? = seen? or Enum.any?(paths, &match?({:ok, _}, File.lstat(&1)))

    receive do
      {:stop, from} -> send(from, {:seen, seen?})
    after
      0 -> watch(paths, seen?)
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

  # The upload id is handed to the user, so the final path must never hold an
  # escaping symlink -- not even for the instant between the unpack and the
  # sanitize. That is why the tree is extracted to a staging directory and the
  # sanitized staging tree is then *renamed* into place. This watches the final
  # path for the whole call, and asserts that the link is never there and that
  # the staged copy is gone once the call returns.
  test "the final path never holds an escaping symlink", %{base: base} do
    stage = Path.join(base, "stage")
    target = Path.join(base, "target")
    marker = "ordering-#{System.unique_integer([:positive])}"
    File.mkdir_p!(stage)
    File.mkdir_p!(target)

    File.write!(Path.join(stage, marker), "hi")
    File.ln_s!("/etc/passwd", Path.join(stage, "leak"))
    File.ln_s!("../outside/secret", Path.join(stage, "escape"))

    archive =
      tar!(Path.join(base, "ordering.tar.gz"), stage, [
        "escape",
        "leak",
        marker
      ])

    watched = [Path.join(target, "leak"), Path.join(target, "escape")]
    watcher = spawn_link(fn -> watch(watched, false) end)

    assert :ok = Archive.safe_extract(archive, target, "10M")

    send(watcher, {:stop, self()})
    assert_receive {:seen, seen?}, 5_000

    refute seen?,
           "an escaping symlink was at the final path before it was sanitized"

    # The final path is the sanitized tree ...
    assert {:error, :enoent} = File.lstat(Path.join(target, "leak"))
    assert {:error, :enoent} = File.lstat(Path.join(target, "escape"))
    assert File.read!(Path.join(target, marker)) == "hi"

    # ... and the staged copy it came from is gone, not left beside it.
    assert staged_markers(marker) == []
  end

  # The ordering is not an accident of timing: the staged tree is sanitized
  # *before* anything is moved. This makes the move fail on purpose -- the
  # target's parent is a regular file, so it cannot be created -- and then
  # inspects what the failure left behind: the staged tree, already sanitized.
  # That staging directory is also exactly what a failure is supposed to leave
  # behind; nothing deletes it.
  test "the staged tree is sanitized before the move", %{base: base} do
    stage = Path.join(base, "stage")
    marker = "staged-#{System.unique_integer([:positive])}"
    File.mkdir_p!(stage)

    File.write!(Path.join(stage, marker), "hi")
    File.ln_s!("/etc/passwd", Path.join(stage, "leak"))
    archive = tar!(Path.join(base, "staged.tar.gz"), stage, ["leak", marker])

    File.write!(Path.join(base, "not-a-dir"), "")
    target = Path.join(base, "not-a-dir/target")

    log =
      capture_log(fn ->
        assert {:error, message} = Archive.safe_extract(archive, target, "10M")
        assert message =~ "could not prepare"
      end)

    # The escaping symlink was removed before the move was attempted ...
    assert log =~ "removing absolute link"
    refute File.exists?(target)

    # ... and the staged tree is still there, with the symlink gone from it.
    assert [staged_marker] = staged_markers(marker)
    staged = Path.dirname(staged_marker)
    on_exit(fn -> File.rm_rf!(staged) end)

    assert File.read!(staged_marker) == "hi"
    assert {:error, :enoent} = File.lstat(Path.join(staged, "leak"))
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

  describe "the target" do
    # The counterexample is `safe_extract(archive, Upload.upload_base(), ...)`:
    # the upload base contains the staging root, so the move would land the tree
    # on the staging area it came from -- and a target of the base itself would
    # put the extracted tree where every upload's own directory lives. Refused
    # before anything is created.
    test "refuses one that is, or contains, the staging root", %{base: base} do
      marker = "target-refused-#{System.unique_integer([:positive])}"
      stage = Path.join(base, "stage")
      File.mkdir_p!(stage)
      File.write!(Path.join(stage, marker), "hi")
      archive = tar!(Path.join(base, "refused.tar.gz"), stage, [marker])

      before = File.ls!(Upload.upload_base())

      for target <- [Upload.upload_base(), Archive.staging_root()] do
        assert {:error, msg} = Archive.safe_extract(archive, target, "10M")
        assert msg =~ "refusing to extract into #{target}"
        assert msg =~ "staging root"
      end

      # Nothing was created, moved or removed: the upload base is exactly as it
      # was, and the marker never landed in it.
      assert File.ls!(Upload.upload_base()) == before
      assert staged_markers(marker) == []

      assert {:error, :enoent} =
               File.lstat(Path.join(Upload.upload_base(), marker))
    end

    # The whole design rests on this: the staging directory is a fresh random
    # name under a directory no upload id can name, so the id the user is handed
    # never names a path that holds an unsanitized tree. Nothing else about the
    # ordering survives a staging path derived from the target.
    test "the staging path is not derived from the target or the upload id", %{
      base: base
    } do
      id = "01234567-89ab-cdef-0123-456789abcdef"
      target = Path.join([base, id, "unpacked"])
      marker = "staging-name-#{System.unique_integer([:positive])}"

      stage = Path.join(base, "stage")
      File.mkdir_p!(stage)
      File.write!(Path.join(stage, marker), "hi")
      archive = tar!(Path.join(base, "staging-name.tar.gz"), stage, [marker])

      # The move cannot happen -- the upload id's own directory is a regular
      # file -- so the staging directory is left behind for inspection, which is
      # exactly what a failure is supposed to leave.
      File.write!(Path.join(base, id), "")

      assert {:error, msg} = Archive.safe_extract(archive, target, "10M")
      assert msg =~ "could not prepare"

      assert [staged_marker] = staged_markers(marker)
      staged = Path.dirname(staged_marker)
      on_exit(fn -> File.rm_rf!(staged) end)

      # It is a random name directly under the staging root, it does not contain
      # the upload id, and it is not built from the target's own name.
      assert Path.dirname(staged) == Archive.staging_root()
      assert Path.basename(staged) =~ ~r/\A[0-9a-f]{16}\z/
      refute String.contains?(staged, id)
      refute String.contains?(staged, Path.basename(target))
    end

    # A populated target is the one case that ever justified deleting anything
    # here, and it is a caller we do not have: `Upload.unpacked_path/1` `mkdir_p`s
    # the target before `safe_extract/3` is called, so it is always an empty
    # directory, and `rename(2)` onto an empty directory succeeds by itself. So
    # it is refused rather than emptied -- saving junk is less dangerous than
    # deleting things.
    test "a populated target is refused, not wiped", %{base: base} do
      marker = "populated-#{System.unique_integer([:positive])}"
      stage = Path.join(base, "stage")
      target = Path.join(base, "target")
      File.mkdir_p!(stage)
      File.mkdir_p!(target)
      File.write!(Path.join(stage, marker), "new")
      File.write!(Path.join(target, "keep.txt"), "keep")
      archive = tar!(Path.join(base, "populated.tar.gz"), stage, [marker])
      on_exit(fn -> cleanup_staged(marker) end)

      assert {:error, msg} = Archive.safe_extract(archive, target, "10M")
      assert msg =~ "could not prepare"
      assert msg =~ "eexist"
      assert msg =~ target

      # Nothing was deleted from the target, and nothing was moved into it.
      assert File.ls!(target) == ["keep.txt"]
      assert File.read!(Path.join(target, "keep.txt")) == "keep"
    end
  end

  describe "the move" do
    # The rename branch is only reachable when `rename(2)` itself fails: by then
    # `remove_existing/1` has refused everything else a rename can fail on (a
    # file, a link, a populated directory), so what a test can build is a
    # cross-device target (`:exdev` -- the failure that is the whole reason
    # staging lives under the upload base) or a target whose parent cannot be
    # written (`:eacces`). The first needs the candidate directory on another
    # filesystem (`/tmp` and `$HOME` are separate btrfs subvolumes here, one
    # ext4 elsewhere), the second needs a process that is not root, so this
    # builds the first one it can. The branch is the same either way.
    test "a rename that cannot happen is a failure, not a merge", %{base: base} do
      marker = "rename-fail-#{System.unique_integer([:positive])}"
      stage = Path.join(base, "stage")
      File.mkdir_p!(stage)
      File.write!(Path.join(stage, marker), "hi")
      archive = tar!(Path.join(base, "rename.tar.gz"), stage, [marker])
      on_exit(fn -> cleanup_staged(marker) end)

      cross_device =
        File.stat!(base).major_device !=
          File.stat!(System.tmp_dir!()).major_device

      target =
        if cross_device do
          parent = Path.join(System.tmp_dir!(), "inkfish-rename-#{marker}")
          on_exit(fn -> File.rm_rf!(parent) end)
          Path.join(parent, "target")
        else
          parent = Path.join(base, "unwritable")
          File.mkdir_p!(parent)
          File.chmod!(parent, 0o500)
          on_exit(fn -> File.chmod(parent, 0o700) end)
          Path.join(parent, "target")
        end

      result = Archive.safe_extract(archive, target, "10M")

      assert match?({:error, _}, result),
             "expected the rename to fail: this test needs the temp dir on " <>
               "another filesystem, or a process that is not root"

      assert {:error, msg} = result
      assert msg =~ "could not move the sanitized tree to #{target}"

      if cross_device do
        assert msg =~ ":exdev"
        assert msg =~ "one filesystem"
        assert msg =~ Archive.staging_root()
      else
        assert msg =~ ":eacces"
      end

      # A failed move leaves the target absent, not half-filled.
      refute File.exists?(target)
    end

    # `make_stage_dir/0`'s own error branch: a staging root that is not a
    # directory is the cheapest way to reach it, and it is the case an operator
    # hits when something else has taken the path.
    test "reports a staging root it cannot create", %{base: base} do
      root = Archive.staging_root()
      File.rm_rf!(root)
      File.write!(root, "")

      on_exit(fn ->
        File.rm_rf!(root)
        File.mkdir_p!(root)
      end)

      stage = Path.join(base, "stage")
      File.mkdir_p!(stage)
      File.write!(Path.join(stage, "f"), "x")
      archive = tar!(Path.join(base, "stage-root.tar.gz"), stage, ["f"])

      assert {:error, msg} =
               Archive.safe_extract(archive, Path.join(base, "target"), "10M")

      assert msg =~ "could not create the staging directory"
      assert msg =~ root
      assert File.regular?(root)
    end
  end

  describe "the canonical fallback" do
    # `System.cmd/3` *raises* `ErlangError` when the binary it is handed is
    # missing, so a `case` on `realpath`'s exit status never sees a missing
    # `realpath` at all: with the executable not resolved first, a `PATH` without
    # `realpath` raised straight out of `safe_extract/3`, which promises
    # `{:ok, _} | {:error, _}`. `canonical/1` now uses the path as it is, and the
    # call fails later, on its own terms.
    test "a missing realpath is reported, not raised", %{base: base} do
      stage = Path.join(base, "stage")
      File.mkdir_p!(stage)
      File.write!(Path.join(stage, "f"), "x")
      archive = tar!(Path.join(base, "no-realpath.tar.gz"), stage, ["f"])

      before = Path.wildcard(Path.join(Archive.staging_root(), "*"))

      path = System.get_env("PATH")
      on_exit(fn -> System.put_env("PATH", path) end)
      System.put_env("PATH", "/nonexistent")

      # The failure is the *next* step's: with no `unshare` on that `PATH` the
      # pipeline cannot even be spawned. Reaching it is the proof that the
      # staging directory was made with the fallback path instead of the call
      # blowing up first.
      assert {:error, msg} =
               Archive.safe_extract(archive, Path.join(base, "target"), "10M")

      assert msg =~ "not found"
      refute msg =~ "could not create the staging directory"

      new = Path.wildcard(Path.join(Archive.staging_root(), "*")) -- before
      on_exit(fn -> Enum.each(new, &File.rm_rf!/1) end)
      assert length(new) == 1
    end
  end

  describe "the readlink fallback" do
    # The same shape as `canonical/1` and the same trap: `System.cmd/3` raises
    # when the binary is missing. A relative link whose target cannot be resolved
    # is removed either way -- that is the rule -- but the log has to say which
    # case it was, rather than the caller of `safe_extract/3` seeing
    # "Erlang error: :enoent".
    test "a missing readlink removes the link and names the reason", %{
      base: base
    } do
      dir = Path.join(base, "links")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "target.txt"), "x")
      link = Path.join(dir, "link")
      File.ln_s!("target.txt", link)

      path = System.get_env("PATH")
      on_exit(fn -> System.put_env("PATH", path) end)
      System.put_env("PATH", "/nonexistent")

      log = capture_log(fn -> Archive.sanitize_links!(dir) end)

      assert log =~ "removing invalid link"
      assert log =~ "readlink was not found on PATH"
      assert {:error, :enoent} = File.lstat(link)
    end
  end

  describe "the sanitize deadline" do
    # The sanitize is one `readlink -f` fork per relative symlink (~0.6 ms
    # measured here), while extracting the same tree is `tar` plus `cp -r`
    # (~0.05 ms per entry): this tree's sanitize costs about ten times
    # everything before it, so a deadline the extraction fits inside is one the
    # sanitize cannot -- and the deadline has to cover it, or the bound the
    # module documents covers less than it says.
    test "a pathological tree of relative symlinks is bounded", %{base: base} do
      links = 8_000
      marker = "deadline-#{System.unique_integer([:positive])}"
      stage = Path.join(base, "many")
      File.mkdir_p!(stage)
      File.write!(Path.join(stage, marker), "hi")

      for i <- 1..links do
        File.ln_s!(marker, Path.join(stage, "link-#{i}"))
      end

      archive = tar!(Path.join(base, "many.tar.gz"), stage, ["."])
      on_exit(fn -> cleanup_staged(marker) end)

      original = Application.get_env(:inkfish, :extract_timeout_ms)

      on_exit(fn ->
        Application.put_env(:inkfish, :extract_timeout_ms, original)
      end)

      Application.put_env(:inkfish, :extract_timeout_ms, 1_500)

      target = Path.join(base, "target")

      {elapsed_us, result} =
        :timer.tc(fn -> Archive.safe_extract(archive, target, "10M") end)

      assert {:error, msg} = result
      assert msg =~ "timed out sanitizing the staged tree"

      # Bounded: the call returns at its deadline rather than after the whole
      # walk, and a tree that could not be finished is never moved into place.
      assert elapsed_us < 5_000_000
      refute File.exists?(target)
    end
  end
end
