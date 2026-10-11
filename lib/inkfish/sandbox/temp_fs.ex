defmodule Inkfish.Sandbox.TempFs do
  @moduledoc """
  Run a command inside a private mount namespace holding a size-limited tmpfs.

  `tmptmpfs` mounts its tmpfs inside a mount namespace that only its own child
  can see, so a path handed back to us would be worthless: the mount does not
  exist in *our* namespace. That is why there is no `make_tempfs/1` any more.
  The command itself has to run inside the namespace, so `run_in_tempfs/4` is
  the only shape that can work.

  The mount, and the directory it lives on, exist exactly as long as the
  command does. Nothing is left in the host mount table.

  ## The helper

  The binary is resolved by `bin/0`, which prefers `:tmptmpfs_bin` over `PATH`
  so that a stale helper earlier on `PATH` cannot be picked up by accident.
  """

  @default_timeout_ms 5_000
  @default_bin "tmptmpfs"
  @env_var "TMPTMPFS_BIN"
  @mount_name "TMPFS"

  @doc """
  Run `cmd` with `args` inside a private mount namespace holding one tmpfs
  capped at `max_size`.

  `max_size` is a tmpfs size string (`"10M"`, `"100m"`, ...). The mount's
  absolute path -- with no trailing slash -- is exported to the command as
  `$#{@mount_name}`. The path is only meaningful inside the namespace.

  Returns `{:ok, output}` when the command exits 0 and `{:error, reason}`
  otherwise. `output` is the command's combined stdout and stderr, because
  both `tmptmpfs` and the command itself diagnose on stderr; `reason` carries
  it too, so a failure says something useful.

  The call is bounded by `:tempfs_timeout_ms` (default `#{@default_timeout_ms}`).
  On timeout the command's whole process group is killed, so nothing is left
  running behind the caller.

  ## Options

    * `:timeout_ms` - override the configured timeout for this call
    * `:mount_name` - the environment variable the mount path is exported as
    * `:env` - extra environment variables, as `{name, value}` pairs
    * `:bin` - override the `tmptmpfs` binary for this call
  """
  def run_in_tempfs(max_size, cmd, args, opts \\ []) do
    helper = Keyword.get(opts, :bin) || bin()
    timeout_ms = Keyword.get(opts, :timeout_ms) || timeout_ms()
    mount_name = Keyword.get(opts, :mount_name) || @mount_name
    env = Keyword.get(opts, :env, [])

    argv = [
      "run",
      "--tmpfs",
      "#{mount_name}=#{max_size}",
      "--",
      to_string(cmd)
      | Enum.map(args, &to_string/1)
    ]

    case System.find_executable(helper) do
      nil -> {:error, "#{helper} not found"}
      path -> run_bounded(path, argv, env, timeout_ms)
    end
  end

  @doc """
  The `tmptmpfs` binary to run.

  `:tmptmpfs_bin` wins when set, then the `#{@env_var}` environment variable,
  and finally the bare name `tmptmpfs` resolved through `PATH`.

  Shell callers share the same override: `priv/scripts/upload_git_clone.sh`
  is expected to invoke `"${#{@env_var}:-tmptmpfs}"` so that one setting points
  both consumers at the same helper.
  """
  def bin do
    Application.get_env(:inkfish, :tmptmpfs_bin) ||
      System.get_env(@env_var) ||
      @default_bin
  end

  defp run_bounded(path, argv, env, timeout_ms) do
    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :exit_status,
        :hide,
        :stderr_to_stdout,
        args: argv,
        env: Enum.map(env, fn {k, v} -> {to_charlist(k), to_charlist(v)} end)
      ])

    deadline = System.monotonic_time(:millisecond) + timeout_ms

    # `Port.open/2` and `Port.info/2` are not atomic, so a command that exits
    # within microseconds of its exec can already be gone by the time we ask for
    # its pid: the port is closed and `:os_pid` comes back `nil`. That is not a
    # failed spawn -- the process ran and finished, and its real
    # `{:exit_status, code}`, along with anything it printed, is already sitting
    # in our mailbox for `collect/5` to read. Reporting `nil` as "could not
    # start" threw that away and turned a correct failure -- `tmptmpfs` failing
    # its mount, for instance -- into a bogus spawn error.
    #
    # The pid is only needed to kill the process group on timeout, and there is
    # nothing left to kill once the process is gone, so `nil` is not a failure
    # here. A spawn that genuinely fails raises out of `Port.open/2` and is
    # reported by the `rescue` below.
    os_pid = os_pid(port)

    collect(port, os_pid, deadline, timeout_ms, [])
  rescue
    error in ErlangError ->
      {:error, "could not run #{path}: #{inspect(error.original)}"}
  end

  # The pid of the port's child, or `nil` when it has already exited -- and so
  # is no longer there to be signalled.
  defp os_pid(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, os_pid} -> os_pid
      nil -> nil
    end
  end

  # The deadline is tracked explicitly rather than reusing the timeout for every
  # message, so a chatty command cannot hold the call open indefinitely.
  defp collect(port, os_pid, deadline, timeout_ms, acc) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      on_timeout(port, os_pid, timeout_ms)
    else
      receive do
        {^port, {:data, data}} ->
          collect(port, os_pid, deadline, timeout_ms, [data | acc])

        {^port, {:exit_status, 0}} ->
          close(port)
          {:ok, IO.iodata_to_binary(Enum.reverse(acc))}

        {^port, {:exit_status, code}} ->
          close(port)
          {:error, exit_reason(code, acc)}
      after
        remaining ->
          on_timeout(port, os_pid, timeout_ms)
      end
    end
  end

  defp on_timeout(port, os_pid, timeout_ms) do
    # A command that is already gone has nothing to kill: the pid exists only to
    # signal the process group, and `nil` means there is no group left. `collect/5`
    # would have read the exit status in that case, so a timeout with no pid is
    # not expected -- but signalling nothing is the right answer either way.
    if os_pid, do: kill_process_group(os_pid)

    flush(port)
    close(port)
    {:error, "timed out after #{timeout_ms}ms"}
  end

  defp exit_reason(code, acc) do
    case acc |> Enum.reverse() |> IO.iodata_to_binary() |> String.trim() do
      "" -> "exited #{code}"
      output -> "exited #{code}: #{output}"
    end
  end

  # `spawn_executable` puts the port's child in a session of its own (erts calls
  # `setsid` for every spawned program), so its process group is its own pid and
  # signalling that group reaches the command's own children as well. We only
  # signal the group when the child really is the group leader, so we can never
  # signal the BEAM's group by accident.
  #
  # Both signals are guarded by a liveness check: reading /proc/<pid>/stat
  # proves the child is still there, so the bare pid cannot have been recycled
  # by an unrelated process before we signal it. When the child is already gone
  # we signal nothing.
  defp kill_process_group(os_pid) do
    case process_group(os_pid) do
      {:ok, pgrp} ->
        if pgrp == os_pid do
          sh("kill -KILL -#{os_pid}")
        end

        sh("kill -KILL #{os_pid}")

      :error ->
        :ok
    end
  end

  # The process group is the third field after the parenthesised command name in
  # /proc/<pid>/stat. Split on the *last* `)` because the name may contain one.
  defp process_group(os_pid) do
    with {:ok, stat} <- File.read("/proc/#{os_pid}/stat"),
         [_state, _ppid, pgrp | _] <-
           stat
           |> String.split(")")
           |> List.last()
           |> String.split(" ", trim: true),
         {pgid, ""} <- Integer.parse(pgrp) do
      {:ok, pgid}
    else
      _ -> :error
    end
  end

  defp sh(command) do
    System.cmd("sh", ["-c", command <> " 2>/dev/null || true"],
      stderr_to_stdout: true
    )
  end

  defp flush(port) do
    receive do
      {^port, _message} -> flush(port)
    after
      0 -> :ok
    end
  end

  defp close(port) do
    if Port.info(port) do
      Port.close(port)
    end
  rescue
    ArgumentError -> :ok
  end

  defp timeout_ms do
    Application.get_env(:inkfish, :tempfs_timeout_ms, @default_timeout_ms)
  end
end
