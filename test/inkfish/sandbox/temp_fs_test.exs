defmodule Inkfish.Sandbox.TempFsTest do
  use Inkfish.DataCase

  alias Inkfish.Sandbox.TempFs

  describe "run_in_one_tempfs/4" do
    test "runs the command in the namespace with the mount path in the environment" do
      assert {:ok, out} =
               TempFs.run_in_one_tempfs("10M", "bash", [
                 "-c",
                 ~s(echo "$TMPFS"; findmnt -no FSTYPE,SIZE "$TMPFS")
               ])

      [path, mount] = String.split(out, "\n", trim: true)

      # The helper's contract: absolute, and never slash-terminated. A trailing
      # slash makes `readlink -f` results look like escapes and deletes every
      # in-tree relative symlink.
      assert String.starts_with?(path, "/")
      refute String.ends_with?(path, "/")

      assert mount =~ "tmpfs"
      assert mount =~ "10M"
    end

    test "enforces the size cap" do
      assert {:error, msg} =
               TempFs.run_in_one_tempfs("1M", "bash", [
                 "-c",
                 ~s(dd if=/dev/zero of="$TMPFS/big" bs=1M count=4)
               ])

      assert msg =~ "No space left on device"
    end

    test "the mount is gone once the command exits" do
      assert {:ok, out} =
               TempFs.run_in_one_tempfs("10M", "bash", [
                 "-c",
                 ~s(echo marker > "$TMPFS/leaked"; echo "$TMPFS")
               ])

      path = String.trim(out)

      refute File.exists?(path)
      refute File.exists?(Path.join(path, "leaked"))

      {mounts, _code} =
        System.cmd("findmnt", ["-T", path, "-no", "FSTYPE"],
          stderr_to_stdout: true
        )

      refute mounts =~ "tmpfs"
    end

    test "kills a command that outlives the timeout and returns quickly" do
      # Regression guard: before the call was bounded this blocked for the full
      # 30s of `sleep`, which is what hung the suite (ExUnit's 60s timeout then
      # fired on every caller).
      {elapsed_us, result} =
        :timer.tc(fn ->
          TempFs.run_in_one_tempfs("10M", "sleep", ["30"], timeout_ms: 200)
        end)

      assert {:error, msg} = result
      assert msg =~ "timed out"
      assert elapsed_us < 5_000_000
    end

    test "kills the whole process group, not just the direct child" do
      marker =
        Path.join(
          System.tmp_dir!(),
          "tempfs_marker_#{System.unique_integer([:positive])}"
        )

      on_exit(fn -> File.rm(marker) end)

      # The backgrounded subshell outlives the shell that spawned it. Killing
      # only the direct child (what `Task.shutdown/2` did) leaves it running, so
      # the marker would appear a second later.
      {elapsed_us, result} =
        :timer.tc(fn ->
          TempFs.run_in_one_tempfs(
            "10M",
            "bash",
            ["-c", ~s{( sleep 1; touch "$INKFISH_MARKER" ) & wait}],
            timeout_ms: 200,
            env: [{"INKFISH_MARKER", marker}]
          )
        end)

      assert {:error, msg} = result
      assert msg =~ "timed out"
      assert elapsed_us < 5_000_000

      Process.sleep(1_500)
      refute File.exists?(marker)
    end

    test "reports a helper binary that does not exist" do
      assert {:error, msg} =
               TempFs.run_in_one_tempfs("10M", "echo", ["hi"],
                 bin: "inkfish-no-such-binary"
               )

      assert msg =~ "not found"
    end

    test "reports a fast-exiting command's own status, never a bogus spawn failure" do
      # `bash -c 'exit 3'` exits 3 within microseconds of the exec.
      # `Port.open/2` and `Port.info/2` are not atomic, so by the time
      # `run_bounded/4` asks for `:os_pid` the port can already be closed --
      # which means "the command has finished", not "the spawn failed". The
      # command's real exit status must be what comes back.
      assert {:error, msg} =
               TempFs.run_in_one_tempfs("10M", "bash", ["-c", "exit 3"])

      assert msg =~ "exited 3"
      refute msg =~ "could not start"
    end

    test "never reports a fast-exiting command as a failed spawn under contention" do
      # Whether the command is already gone by the time `run_bounded/4` asks for
      # `:os_pid` is up to the scheduler, so a single call cannot be relied on to
      # exercise the closed-port path. Running many at once -- and doing it on a
      # loaded machine -- is what gives that path a chance to be hit, which is
      # how the flake showed up in the first place. The assertion holds either
      # way; the point is that it must keep holding when the race is lost.
      #
      # `exit 3` keeps this a fast failure: the mount happens and then the
      # command is gone within microseconds, which is the exit the race needs.
      results =
        1..64
        |> Task.async_stream(
          fn _ ->
            TempFs.run_in_one_tempfs("10M", "bash", ["-c", "exit 3"],
              timeout_ms: 10_000
            )
          end,
          max_concurrency: 64,
          timeout: :infinity
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert length(results) == 64

      Enum.each(results, fn result ->
        assert {:error, msg} = result
        assert msg =~ "exited 3"
        refute msg =~ "could not start"
      end)
    end
  end

  describe "run_in_tempfs/4" do
    test "mounts one capped tmpfs per entry, exported under its own name" do
      assert {:ok, out} =
               TempFs.run_in_tempfs(
                 [{"CLONE_TMP", "100m"}, {"PERSIST_TMP", "5m"}],
                 "bash",
                 [
                   "-c",
                   ~s(echo "$CLONE_TMP"; echo "$PERSIST_TMP"; ) <>
                     ~s(findmnt -no SIZE -b "$CLONE_TMP"; ) <>
                     ~s(findmnt -no SIZE -b "$PERSIST_TMP")
                 ]
               )

      [clone, persist, clone_size, persist_size] =
        String.split(out, "\n", trim: true)

      # Both paths are absolute and slash-free -- the contract the sanitizer's
      # raw-base comparison depends on -- and they are two distinct mounts, each
      # capped at its own size (in bytes, so the unit findmnt would print does
      # not enter into it).
      assert String.starts_with?(clone, "/")
      refute String.ends_with?(clone, "/")
      assert String.starts_with?(persist, "/")
      refute String.ends_with?(persist, "/")
      refute clone == persist

      assert clone_size == "104857600"
      assert persist_size == "5242880"

      # ...and neither one leaks into our namespace when the command exits.
      refute File.exists?(clone)
      refute File.exists?(persist)
    end

    test "surfaces a preamble failure in the namespace, with its own diagnostic" do
      # The preamble puts its anchor tmpfs under `$TMPDIR`, so a `$TMPDIR` that
      # cannot be created makes the preamble itself fail: `set -e` stops it
      # before it mounts anything, and the caller gets `mkdir`'s own message
      # rather than a silent empty tree.
      base =
        Path.join(
          System.tmp_dir!(),
          "tempfs_test_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(base)
      on_exit(fn -> File.rm_rf!(base) end)

      not_a_dir = Path.join(base, "not-a-dir")
      File.write!(not_a_dir, "not a directory")

      assert {:error, msg} =
               TempFs.run_in_one_tempfs("10M", "bash", ["-c", "echo hi"],
                 env: [{"TMPDIR", Path.join(not_a_dir, "sub")}]
               )

      assert msg =~ "exited 1"
      assert msg =~ "Not a directory"
    end
  end

  describe "mount validation" do
    # The mount name and the size are both interpolated into the shell preamble,
    # so both are checked in Elixir, before anything is spawned: a bad one is
    # refused with a message that names it, and there is no shell-metacharacter
    # surface left for the preamble to worry about. `unshare_argv/3` builds the
    # argv without spawning anything, so a rejection from it is proof the check
    # is ours and not the shell's.
    test "rejects a bad size, naming it" do
      assert {:error, msg} =
               TempFs.unshare_argv([{"TMPFS", "1X"}], "bash", ["-c", "echo hi"])

      assert msg =~ "invalid tmpfs size"
      assert msg =~ ~s("1X")
    end

    test "rejects a size that would smuggle in a second mount option" do
      assert {:error, msg} =
               TempFs.unshare_argv(
                 [{"TMPFS", "10M,inkfish_no_such_option"}],
                 "bash",
                 ["-c", "echo hi"]
               )

      assert msg =~ "invalid tmpfs size"
      assert msg =~ "inkfish_no_such_option"
    end

    test "rejects a bad mount name, naming it" do
      name = "TMPFS; touch /tmp/inkfish-pwned"

      assert {:error, msg} =
               TempFs.unshare_argv([{name, "10M"}], "bash", ["-c", "echo hi"])

      assert msg =~ "invalid mount name"
      assert msg =~ name
    end

    test "checks every mount, not just the first" do
      assert {:error, msg} =
               TempFs.unshare_argv(
                 [{"CLONE_TMP", "100m"}, {"PERSIST_TMP", "5m "}],
                 "bash",
                 ["-c", "echo hi"]
               )

      assert msg =~ "invalid tmpfs size"
      assert msg =~ ~s("5m ")
    end

    test "rejects a bad size before it even resolves the binary" do
      # Nothing is spawned for a bad size -- not even the binary lookup -- so the
      # error is the size's, and not the (also missing) binary's.
      assert {:error, msg} =
               TempFs.run_in_tempfs(
                 [{"TMPFS", "1X"}],
                 "bash",
                 ["-c", "echo hi"],
                 bin: "inkfish-no-such-binary"
               )

      assert msg =~ "invalid tmpfs size"
      refute msg =~ "not found"
    end

    test "accepts the sizes tmpfs itself accepts" do
      for size <- ["10M", "512k", "1g", "100K", "1T", "50%", "1024"] do
        assert {:ok, argv} = TempFs.unshare_argv([{"TMPFS", size}], "bash", [])
        assert Enum.any?(argv, &(&1 =~ "size=#{size}"))
      end
    end

    test "resolves the unshare binary, and explains a missing one" do
      # `Inkfish.Application` calls `unshare_bin/0` once at boot; it is the
      # resolution `unshare_argv/3` does, minus the `:bin` override.
      assert {:ok, path} = TempFs.unshare_bin()
      assert Path.type(path) == :absolute
      assert File.exists?(path)

      log = TempFs.missing_unshare_log_message()
      assert log =~ "unshare"
      assert log =~ "PATH"
      assert log =~ "misconfiguration"
    end
  end

  describe "a kernel refusal" do
    # The size guard deliberately forbids anything that could smuggle in a
    # second mount option, so a kernel refusal is not reachable through
    # `run_in_tempfs/4` any more: every size it lets through is one tmpfs
    # mounts. This drives the same invocation the module builds -- `unshare`
    # creating the namespaces, `bash` running a preamble that mounts the capped
    # tmpfs -- with one option tmpfs does not know, which is an EINVAL from
    # `mount(2)` and nothing else.
    #
    # What comes back is the point: `mount(8)` maps every EINVAL onto a single
    # generic sentence, so this is the wording a kernel refusal has always
    # produced here, and the wording the assertions above no longer expect. The
    # kernel's own text is not obtainable through `mount(8)` at all -- which is
    # exactly why a size the kernel would refuse is refused by us first, where
    # we can still name it.
    test "is reported as libmount's own wording, which never names the option" do
      script = """
      set -e
      anchor="$(realpath -m -- "${TMPDIR:-/tmp}")/inkfish-tmpfs-unknown-option"
      mkdir -p "$anchor"
      mount -t tmpfs -o mode=0700 tmpfs "$anchor"
      mount_path="$anchor/TMPFS"
      mkdir "$mount_path"
      mount -t tmpfs -o "size=10M,inkfish_no_such_option" tmpfs "$mount_path"
      """

      {out, code} =
        System.cmd(
          TempFs.bin(),
          ["-Urm", "--propagation", "private", "--", "bash", "-c", script],
          stderr_to_stdout: true
        )

      refute code == 0
      assert out =~ "wrong fs type, bad option"
      refute out =~ "invalid tmpfs size"
    end
  end
end
