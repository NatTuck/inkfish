defmodule Inkfish.Sandbox.TempFs do
  @moduledoc """
  Run a command inside a private mount namespace holding a size-limited tmpfs.

  The namespace is built by util-linux `unshare(1)`, which this module runs
  directly:

      unshare -Urm --propagation private -- bash -c '<preamble>; exec "$@"' bash CMD ARGS...

  `-U` creates an unprivileged user namespace and `-r` maps the caller onto uid
  0 inside it, which is what makes mounting possible with no privilege on the
  host; `-m` creates a private mount namespace, and `--propagation private`
  keeps everything mounted in it out of the host's mount table. The shell
  `unshare` starts builds the mount point, mounts the size-capped tmpfs there,
  exports its path, and `exec`s the caller's command, so the command's own exit
  status and signals are the ones the port reports. The same shell refuses a
  size that tmpfs would not accept, before it mounts anything, so a bad size is
  reported as a bad size rather than as `mount(8)`'s generic "wrong fs type, bad
  option" sentence.

  The tmpfs is mounted in a mount namespace that only that shell and its
  children can see, so a path handed back to us would be worthless: the mount
  does not exist in *our* namespace. That is why there is no `make_tempfs/1`
  any more. The command itself has to run inside the namespace, so
  `run_in_tempfs/4` is the only shape that can work.

  The mount, and the directory it lives on, exist exactly as long as the
  command does. Nothing is left in the host mount table.

  ## The binary

  There is no helper program and no setuid bit: `bin/0` is util-linux's
  `unshare(1)`, resolved through `PATH`. Nothing is compiled or installed for
  this, so there is no stale copy to prefer over the `PATH` one either.
  """

  @default_timeout_ms 5_000
  @default_bin "unshare"
  @mount_name "TMPFS"

  # The mount name becomes an environment variable name and a path component,
  # and the size becomes part of the tmpfs option string, both inside the shell
  # script below. Neither is user input today, but both are interpolated, so
  # neither is allowed to carry anything that could smuggle in extra shell
  # syntax or extra mount options.
  @name_format ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/
  @size_format ~r/\A[^\s,'"`\\$]*\z/

  # The size *grammar* -- a byte count, a byte count with one unit suffix, or a
  # percentage of physical memory -- as the ERE the shell in `preamble/2`
  # applies before it mounts anything. It has to be no stricter than tmpfs
  # itself, so that a size which would have mounted is never turned into a
  # failure: `10M`, `512k`, `1g`, `100K`, `1T`, `50%` and a bare `1024` all
  # mount, so all of them pass. (tmpfs's own parser also takes a `0x` hex byte
  # count; no caller here means one, and saying so is better than mounting a
  # size nobody asked for.)
  #
  # It has to be checked in the shell rather than here. `unshare` runs the
  # preamble, so the preamble's exit status and diagnostic are the *command's*:
  # a malformed size then fails the way every other bad mount does, quickly and
  # with its reason attached. Rejecting in Elixir would return before a port was
  # ever opened, which is exactly the case `run_bounded/4`'s closed-port
  # handling exists to get right, and it would report nothing about the mount.
  #
  # Our own message is the only precise one available. `mount(8)` maps every
  # EINVAL from `mount(2)` onto a single generic sentence -- "wrong fs type, bad
  # option, bad superblock on tmpfs, missing codepage or helper program, or
  # other error" -- which names everything except the size, so a size the kernel
  # refuses comes back saying nothing about the size at all.
  @size_ok ~s{^[0-9]+([kKmMgGtTpPeE]|%)?$}

  @doc """
  Run `cmd` with `args` inside a private mount namespace holding one tmpfs
  capped at `max_size`.

  `max_size` is a tmpfs size string (`"10M"`, `"100m"`, ...). A size tmpfs
  itself would not accept is refused inside the namespace before the mount is
  attempted, so the error names the size instead of coming back as `mount(8)`'s
  generic sentence. The mount's absolute path -- with no trailing slash -- is
  exported to the command as `$#{@mount_name}`. The path is only meaningful
  inside the namespace.

  Returns `{:ok, output}` when the command exits 0 and `{:error, reason}`
  otherwise. `output` is the command's combined stdout and stderr, because
  both the mount and the command itself diagnose on stderr; `reason` carries
  it too, so a failure says something useful.

  The call is bounded by `:tempfs_timeout_ms` (default `#{@default_timeout_ms}`).
  On timeout the command's whole process group is killed, so nothing is left
  running behind the caller.

  ## Options

    * `:timeout_ms` - override the configured timeout for this call
    * `:mount_name` - the environment variable the mount path is exported as
    * `:env` - extra environment variables, as `{name, value}` pairs
    * `:bin` - override the `unshare` binary for this call
  """
  def run_in_tempfs(max_size, cmd, args, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms) || timeout_ms()
    mount_name = Keyword.get(opts, :mount_name) || @mount_name
    env = Keyword.get(opts, :env, [])

    # `:bin` names a specific `unshare` -- the tests use it to exercise the
    # missing-binary path; otherwise it is util-linux's, resolved through
    # `PATH`.
    helper = Keyword.get(opts, :bin) || bin()

    with :ok <- check_mount_name(mount_name),
         :ok <- check_size(max_size) do
      case System.find_executable(helper) do
        nil ->
          {:error, "#{helper} not found"}

        path ->
          run_bounded(
            path,
            argv(max_size, mount_name, cmd, args),
            env,
            timeout_ms
          )
      end
    end
  end

  @doc """
  The `unshare` binary to run.

  Always util-linux's `unshare(1)`, resolved through `PATH`: `unshare -Urm`
  gets the privileges it needs from an unprivileged user namespace, so there is
  no compiled artifact to point at and nothing to install.
  """
  def bin do
    @default_bin
  end

  # The whole argv: `unshare` creates the namespaces, `bash` runs the preamble
  # that mounts the tmpfs, and the preamble's `exec "$@"` hands the shell over
  # to the caller's command. Passing the command as `bash`'s positional
  # parameters (rather than splicing it into the script text) is what keeps it
  # out of the shell's parsing.
  defp argv(max_size, mount_name, cmd, args) do
    [
      "-Urm",
      "--propagation",
      "private",
      "--",
      "bash",
      "-c",
      preamble(max_size, mount_name) <> ~s(exec "$@"),
      "bash",
      to_string(cmd) | Enum.map(args, &to_string/1)
    ]
  end

  # The shell `unshare` runs. It refuses a malformed size before it mounts
  # anything -- with its own message, because `mount(8)` has no way to say which
  # option the kernel disliked -- then mounts a private anchor tmpfs, creates the
  # mount point inside it and mounts the size-capped tmpfs there, so the
  # directory and the mount both vanish with the namespace instead of being left
  # behind on the host. It then exports the mount path and `exec`s the caller's
  # command.
  #
  # The mount path must be ABSOLUTE with NO TRAILING SLASH. The sanitizer
  # compares the raw base string against `readlink -f` output, which is always
  # absolute and resolved, so a relative or slash-terminated base makes every
  # in-tree relative symlink look like an escape and deletes it. `realpath -m`
  # is what canonicalises the anchor (including a `TMPDIR` that is relative or
  # ends in a slash) before the path is built from it.
  defp preamble(max_size, mount_name) do
    """
    set -e
    size='#{max_size}'
    if [[ ! "$size" =~ #{@size_ok} ]]; then
      echo "invalid tmpfs size: \\"$size\\"" >&2
      exit 1
    fi
    anchor="${TMPDIR:-/tmp}"
    case "$anchor" in
      /*) ;;
      *) anchor=/tmp ;;
    esac
    anchor="$(realpath -m -- "$anchor")/inkfish-tmpfs"
    mkdir -p "$anchor"
    mount -t tmpfs -o mode=0700 tmpfs "$anchor"
    mount_path="$anchor/#{mount_name}"
    mkdir "$mount_path"
    mount -t tmpfs -o "size=#{max_size}" tmpfs "$mount_path"
    export #{mount_name}="$mount_path"
    """
  end

  defp check_mount_name(mount_name) do
    if String.match?(mount_name, @name_format) do
      :ok
    else
      {:error, "invalid mount name #{inspect(mount_name)}"}
    end
  end

  # The smuggling filter for the size. It says nothing about whether the size is
  # a size at all: `@size_ok` decides that, in the preamble, so that the failure
  # is the command's. This only keeps a size from carrying shell syntax or a
  # second mount option into the script.
  defp check_size(max_size) do
    if String.match?(max_size, @size_format) do
      :ok
    else
      {:error, "invalid size #{inspect(max_size)}"}
    end
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
    # start" threw that away and turned a correct failure -- a mount that fails
    # within microseconds of the exec, for instance -- into a bogus spawn error.
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
  # signalling that group reaches the command's own children as well -- and
  # `unshare` does not fork, it `exec`s the shell, so the group leader is the
  # mount and the command both. We only signal the group when the child really
  # is the group leader, so we can never signal the BEAM's group by accident.
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
