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
      # `1X` is not a tmpfs size option, so the helper's mount fails and it exits
      # 1 within microseconds. `Port.open/2` and `Port.info/2` are not atomic, so
      # by the time `run_bounded/4` asks for `:os_pid` the port can already be
      # closed -- which means "the command has finished", not "the spawn
      # failed". The helper's real exit status and diagnostic must be what comes
      # back.
      assert {:error, msg} =
               TempFs.run_in_tempfs("1X", "bash", ["-c", "echo hi"])

      assert msg =~ "Invalid argument"
      refute msg =~ "could not start"
    end

    test "never reports a fast-exiting command as a failed spawn under contention" do
      # Whether the helper is already gone by the time `run_bounded/4` asks for
      # `:os_pid` is up to the scheduler, so a single call cannot be relied on to
      # exercise the closed-port path. Running many at once -- and doing it on a
      # loaded machine -- is what gives that path a chance to be hit, which is
      # how the flake showed up in the first place. The assertion holds either
      # way; the point is that it must keep holding when the race is lost.
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
        assert msg =~ "Invalid argument"
        refute msg =~ "could not start"
      end)
    end
  end
end
