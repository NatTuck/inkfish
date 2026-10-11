defmodule Inkfish.Sandbox.TempFsTest do
  use Inkfish.DataCase

  alias Inkfish.Sandbox.TempFs

  describe "run_in_tempfs/4" do
    test "runs the command in the namespace with the mount path in the environment" do
      assert {:ok, out} =
               TempFs.run_in_tempfs("10M", "bash", [
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
               TempFs.run_in_tempfs("1M", "bash", [
                 "-c",
                 ~s(dd if=/dev/zero of="$TMPFS/big" bs=1M count=4)
               ])

      assert msg =~ "No space left on device"
    end

    test "the mount is gone once the command exits" do
      assert {:ok, out} =
               TempFs.run_in_tempfs("10M", "bash", [
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
          TempFs.run_in_tempfs("10M", "sleep", ["30"], timeout_ms: 200)
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
          TempFs.run_in_tempfs(
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
               TempFs.run_in_tempfs("10M", "echo", ["hi"],
                 bin: "inkfish-no-such-binary"
               )

      assert msg =~ "not found"
    end

    test "reports a fast-exiting command's own status, never a bogus spawn failure" do
      # `1X` is not a tmpfs size, so the preamble refuses it before it mounts
      # anything and the command exits 1 within microseconds. `Port.open/2` and
      # `Port.info/2` are not atomic, so by the time `run_bounded/4` asks for
      # `:os_pid` the port can already be closed -- which means "the command has
      # finished", not "the spawn failed". The command's real exit status and
      # diagnostic -- here its own, precise complaint about the size -- must be
      # what comes back.
      assert {:error, msg} =
               TempFs.run_in_tempfs("1X", "bash", ["-c", "echo hi"])

      assert msg =~ "invalid tmpfs size"
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
      # `1X` keeps this a fast failure without asking the kernel for one: the
      # preamble rejects it and exits before the mount, which is the same
      # microseconds-early exit the race needs.
      results =
        1..64
        |> Task.async_stream(
          fn _ ->
            TempFs.run_in_tempfs("1X", "bash", ["-c", "echo hi"],
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
        assert msg =~ "invalid tmpfs size"
        refute msg =~ "could not start"
      end)
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
    # exactly why a size the kernel would refuse is now refused by us first,
    # where we can still name it.
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
