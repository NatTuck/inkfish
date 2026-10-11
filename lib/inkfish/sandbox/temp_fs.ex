defmodule Inkfish.Sandbox.TempFs do
  @moduledoc """
  Run a command inside a private mount namespace holding named, size-limited
  tmpfs mounts.

  The namespace is built by util-linux `unshare(1)`, which this module runs
  directly:

      unshare -Urm --propagation private -- bash -c '<preamble>; exec "$@"' bash CMD ARGS...

  `-U` creates an unprivileged user namespace and `-r` maps the caller onto uid
  0 inside it, which is what makes mounting possible with no privilege on the
  host; `-m` creates a private mount namespace, and `--propagation private`
  keeps everything mounted in it out of the host's mount table. The shell
  `unshare` starts mounts a private anchor tmpfs, mounts one size-capped tmpfs
  per requested mount inside it, exports each mount's path under its own name,
  and `exec`s the caller's command, so the command's own exit status and signals
  are the ones the port reports.

  This module is the single place that knows that argv, and both callers go
  through it: `run_in_tempfs/4` (and its single-mount convenience,
  `run_in_one_tempfs/4`) spawns it through a bounded port, while
  `Inkfish.Uploads.Git.start_clone/1` hands `unshare_argv/3`'s argv to
  `Inkfish.Ittys`, which keeps its own supervision and streaming. The clone
  script is a plain script as a result: it used to re-exec itself under
  `unshare` and mount its own two tmpfs, with a recursion marker to keep the
  re-exec from looping, and now it only asserts that its mounts are there.

  The mounts live in a mount namespace that only that shell and its children
  can see, so a path handed back to us would be worthless: the mount does not
  exist in *our* namespace. That is why there is no `make_tempfs/1` any more.
  The command itself has to run inside the namespace, so `run_in_tempfs/4` is
  the only shape that can work.

  The mounts, and the directories they live on, exist exactly as long as the
  command does. Nothing is left in the host mount table.

  ## Names and sizes

  A mount is a `{name, size}` pair: `name` is the environment variable the
  mount's absolute path is exported as, and `size` is a tmpfs size string
  (`"10M"`, `"100m"`, ...). Both are validated here, in Elixir, before anything
  is spawned -- see `unshare_argv/3` -- so neither can carry shell syntax or a
  second mount option into the preamble, and a rejection names the offending
  value. The preamble therefore has no validation of its own.

  ## The binary

  There is no helper program and no setuid bit: `bin/0` is util-linux's
  `unshare(1)`, resolved through `PATH`. Nothing is compiled or installed for
  this, so there is no stale copy to prefer over the `PATH` one either.

  Resolving the binary does not mean the namespace can be created -- a host can
  have `unshare` installed and still refuse it -- so the boot check is
  `check_userns/1`, which creates the namespace for real.
  """

  @default_timeout_ms 5_000
  @default_bin "unshare"

  # The boot probe's own bound and command. The probe creates the namespaces
  # and runs nothing, so it finishes in milliseconds; the bound is only there so
  # a wedged `unshare` cannot hold up boot.
  @default_probe_timeout_ms 5_000
  @default_probe_cmd "true"

  # The mount `run_in_one_tempfs/4` makes, and the name the scripts it runs read
  # the mount path from.
  @mount_name "TMPFS"

  # The mount name becomes an environment variable name and a path component,
  # and the size becomes part of the tmpfs option string, both inside the shell
  # script below. Neither is user input today, but both are interpolated, so
  # neither is allowed to carry anything that could smuggle in extra shell
  # syntax or extra mount options.
  @name_format ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/

  # The size grammar: a byte count with an optional single unit suffix, or a
  # percentage of physical memory. It has to be no stricter than tmpfs itself,
  # so that a size which would have mounted is never turned into a failure:
  # `10M`, `512k`, `1g`, `100K`, `1T`, `50%` and a bare `1024` all mount, so all
  # of them pass. (tmpfs's own parser also takes a `0x` hex byte count; no
  # caller here means one, and saying so is better than mounting a size nobody
  # asked for.)
  #
  # Our own message is the only precise one available. `mount(8)` maps every
  # EINVAL from `mount(2)` onto a single generic sentence -- "wrong fs type, bad
  # option, bad superblock on tmpfs, missing codepage or helper program, or
  # other error" -- which names everything except the size, so a size the kernel
  # refuses comes back saying nothing about the size at all. Checking here, with
  # a message that quotes the offending size, is what keeps that from being the
  # only thing a bad size can produce.
  @size_format ~r/\A[0-9]+[kKmMgGtTpPeE%]?\z/

  @missing_unshare_log_message "the `unshare` binary that creates the sandbox " <>
                                 "mount namespace could not be resolved: no " <>
                                 "`unshare` executable was found on `PATH`. This " <>
                                 "is a deployment misconfiguration and every " <>
                                 "archive upload, submission and git clone will " <>
                                 "fail until it is fixed: install util-linux " <>
                                 "(which provides `unshare`), or make `unshare` " <>
                                 "available on `PATH`."

  @doc """
  The complete `unshare` argv that runs `cmd` with `args` inside a namespace
  holding one size-capped tmpfs per entry of `mounts`.

  `mounts` is a list of `{name, size}` pairs, e.g.
  `[{"CLONE_TMP", "100m"}, {"PERSIST_TMP", "5m"}]`. Each name is exported into
  the command's environment holding that mount's absolute path (no trailing
  slash); each size caps the tmpfs mounted there.

  Returns `{:ok, argv}` -- with the resolved absolute path of `unshare` as
  `argv`'s first element, so the argv can be `exec`ed as-is -- or
  `{:error, reason}` when a name or a size is invalid, naming the offending
  value, or when the `unshare` binary cannot be found.

  The first element is resolved here rather than left as the bare name
  `unshare` because `Inkfish.Ittys` runs the argv with `execve(2)` and no shell,
  and `execve(2)` does not search `PATH`.
  """
  def unshare_argv(mounts, cmd, args, opts \\ []) do
    with :ok <- check_mounts(mounts),
         {:ok, exe} <- resolve(Keyword.get(opts, :bin)) do
      {:ok, [exe | argv_tail(mounts, cmd, args)]}
    end
  end

  @doc """
  Run `cmd` with `args` inside a private mount namespace holding one size-capped
  tmpfs per entry of `mounts`.

  `mounts` is a list of `{name, size}` pairs; see `unshare_argv/3`. The mounts'
  absolute paths -- with no trailing slash -- are exported to the command under
  their own names. The paths are only meaningful inside the namespace.

  Returns `{:ok, output}` when the command exits 0 and `{:error, reason}`
  otherwise. `output` is the command's combined stdout and stderr, because both
  the mount and the command itself diagnose on stderr; `reason` carries it too,
  so a failure says something useful.

  The call is bounded by `:tempfs_timeout_ms` (default `#{@default_timeout_ms}`).
  On timeout the command's whole process group is killed, so nothing is left
  running behind the caller.

  ## Options

    * `:timeout_ms` - override the configured timeout for this call
    * `:env` - extra environment variables, as `{name, value}` pairs
    * `:bin` - override the `unshare` binary for this call
  """
  def run_in_tempfs(mounts, cmd, args, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms) || timeout_ms()
    env = Keyword.get(opts, :env, [])

    with {:ok, [exe | rest]} <- unshare_argv(mounts, cmd, args, opts) do
      run_bounded(exe, rest, env, timeout_ms)
    end
  end

  @doc """
  Run `cmd` with `args` inside a private mount namespace holding one tmpfs
  capped at `max_size`.

  The single-mount convenience around `run_in_tempfs/4`: the mount is named
  `#{@mount_name}`, which is the name the extraction scripts read the mount path
  from. `max_size` is a tmpfs size string (`"10M"`, `"100m"`, ...); a size tmpfs
  itself would not accept is rejected here, naming it, before anything is
  spawned.

  The options are `run_in_tempfs/4`'s.
  """
  def run_in_one_tempfs(max_size, cmd, args, opts \\ []) do
    run_in_tempfs([{@mount_name, max_size}], cmd, args, opts)
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

  @doc """
  The `unshare` executable, resolved through `PATH`.

  Returns `{:ok, path}`, or `{:error, reason}` naming the binary that could not
  be found. The deployment-level explanation is
  `missing_unshare_log_message/0`.
  """
  def unshare_bin do
    resolve(nil)
  end

  @doc """
  The operator-facing explanation of a missing `unshare` binary.

  Log only: it spells out the consequence for the whole deployment, which is
  what `Inkfish.Application` reports once at boot.
  """
  def missing_unshare_log_message do
    @missing_unshare_log_message
  end

  @doc """
  Check that this host can actually create an unprivileged user namespace.

  Resolves `unshare` and runs `unshare -Urm -- true`: the `-U` (user namespace),
  `-r` (map the caller onto uid 0 inside it) and `-m` (private mount namespace)
  every real invocation needs, with nothing mounted and nothing run. The binary
  being present is not enough -- a host can have `unshare` installed and still
  refuse the namespace, which is exactly what
  `kernel.apparmor_restrict_unprivileged_userns=1` (the Ubuntu 23.10+/24.04
  default) and a container's `CLONE_NEWUSER`-blocking seccomp profile do -- so
  this runs the mechanism instead of trusting `PATH`.

  Returns `:ok`, or `{:error, message}` where `message` is the operator-facing
  explanation `Inkfish.Application` logs once at boot: the missing-`unshare`
  text (`missing_unshare_log_message/0`) when the binary cannot be resolved, or
  `userns_probe_log_message/1` -- which carries the probe's own output, stderr
  included -- when it resolves but the namespace cannot be created.

  The call is bounded by `:userns_probe_timeout_ms` (default
  `#{@default_probe_timeout_ms}`), so a probe that hangs cannot hold up boot.

  ## Options

    * `:probe` - the `{cmd, args}` the namespace runs instead of `true`
    * `:bin` - override the `unshare` binary for this call
    * `:timeout_ms` - override the configured timeout for this call

  `:probe` and the timeout also come from the `:userns_probe` and
  `:userns_probe_timeout_ms` config, so a deployment can change what the boot
  check runs without a code change.
  """
  def check_userns(opts \\ []) do
    case probe_bin(opts) do
      {:ok, exe} ->
        {cmd, args} = probe(opts)
        argv = ["-Urm", "--", to_string(cmd) | Enum.map(args, &to_string/1)]

        case run_bounded(exe, argv, [], probe_timeout_ms(opts)) do
          {:ok, _output} -> :ok
          {:error, reason} -> {:error, userns_probe_log_message(reason)}
        end

      {:error, _reason} ->
        {:error, @missing_unshare_log_message}
    end
  end

  @doc """
  The operator-facing explanation of a probe that could not create a user
  namespace, carrying the probe's own output in `reason`.

  Log only: it spells out the consequence for the whole deployment and the host
  knobs that decide it, which is what `Inkfish.Application` reports once at
  boot.
  """
  def userns_probe_log_message(reason) do
    "the tmpfs sandbox cannot create a user namespace (`unshare -Urm`), so " <>
      "every archive upload, submission and git clone will fail. The probe " <>
      "failed with: #{reason}. Check that this host allows unprivileged user " <>
      "namespaces: `kernel.apparmor_restrict_unprivileged_userns` is 1 by " <>
      "default on Ubuntu 23.10+/24.04, and denies the `unshare(2)` call " <>
      "unless the process has an AppArmor profile that permits it -- set it " <>
      "to 0, or install such a profile. On kernels that have " <>
      "`kernel.unprivileged_userns_clone`, it must be 1. In a container, a " <>
      "seccomp profile that blocks `CLONE_NEWUSER` denies it regardless of " <>
      "those sysctls."
  end

  # The probe resolves the binary the way `unshare_bin/0` does -- that is the
  # resolution the boot check reports on -- and honours `:bin` the way
  # `unshare_argv/3` does.
  defp probe_bin(opts) do
    case Keyword.get(opts, :bin) do
      nil -> unshare_bin()
      helper -> resolve(helper)
    end
  end

  # What the probe runs inside the namespace: the `:probe` option wins, then the
  # config, then `true`. A bare command is taken as one with no arguments, so a
  # config value written as `{"false", []}` and one written as `"false"` both
  # work.
  defp probe(opts) do
    case Keyword.get(opts, :probe) ||
           Application.get_env(
             :inkfish,
             :userns_probe,
             {@default_probe_cmd, []}
           ) do
      {cmd, args} -> {cmd, List.wrap(args)}
      cmd -> {cmd, []}
    end
  end

  defp probe_timeout_ms(opts) do
    Keyword.get(opts, :timeout_ms) ||
      Application.get_env(
        :inkfish,
        :userns_probe_timeout_ms,
        @default_probe_timeout_ms
      )
  end

  # `:bin` names a specific `unshare` -- the tests use it to exercise the
  # missing-binary path; otherwise it is util-linux's, resolved through `PATH`.
  defp resolve(helper) do
    helper = helper || bin()

    case System.find_executable(helper) do
      nil -> {:error, "#{helper} not found"}
      path -> {:ok, path}
    end
  end

  # The whole argv, less the `unshare` binary itself: `unshare` creates the
  # namespaces, `bash` runs the preamble that mounts the tmpfs, and the
  # preamble's `exec "$@"` hands the shell over to the caller's command. Passing
  # the command as `bash`'s positional parameters (rather than splicing it into
  # the script text) is what keeps it out of the shell's parsing.
  defp argv_tail(mounts, cmd, args) do
    [
      "-Urm",
      "--propagation",
      "private",
      "--",
      "bash",
      "-c",
      preamble(mounts),
      "bash",
      to_string(cmd) | Enum.map(args, &to_string/1)
    ]
  end

  # The shell `unshare` runs. It mounts a private anchor tmpfs, then, for each
  # requested mount, creates a mount point inside that anchor and mounts the
  # size-capped tmpfs there -- so the directories and the mounts both vanish with
  # the namespace instead of being left behind on the host. Each mount path is
  # then exported under the name the caller gave it, and the shell `exec`s the
  # caller's command.
  #
  # The names and sizes are validated in `unshare_argv/3` before this text is
  # built, so they are interpolated as-is and no metacharacter can reach it.
  #
  # The mount path must be ABSOLUTE with NO TRAILING SLASH. The sanitizer
  # compares the raw base string against `readlink -f` output, which is always
  # absolute and resolved, so a relative or slash-terminated base makes every
  # in-tree relative symlink look like an escape and deletes it. `realpath -m`
  # is what canonicalises the anchor (including a `TMPDIR` that is relative or
  # ends in a slash) before the paths are built from it.
  defp preamble(mounts) do
    blocks =
      Enum.map_join(mounts, "", fn {name, size} ->
        """
        mount_path="$anchor/#{name}"
        mkdir "$mount_path"
        mount -t tmpfs -o "size=#{size}" tmpfs "$mount_path"
        export #{name}="$mount_path"
        """
      end)

    """
    set -e
    anchor="${TMPDIR:-/tmp}"
    case "$anchor" in
      /*) ;;
      *) anchor=/tmp ;;
    esac
    anchor="$(realpath -m -- "$anchor")/inkfish-tmpfs"
    mkdir -p "$anchor"
    mount -t tmpfs -o mode=0700 tmpfs "$anchor"
    #{blocks}
    exec "$@"
    """
  end

  defp check_mounts(mounts) do
    Enum.reduce_while(mounts, :ok, fn {name, size}, :ok ->
      with :ok <- check_mount_name(name),
           :ok <- check_size(size) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp check_mount_name(mount_name) do
    if String.match?(mount_name, @name_format) do
      :ok
    else
      {:error, "invalid mount name: #{inspect(mount_name)}"}
    end
  end

  defp check_size(max_size) do
    if String.match?(max_size, @size_format) do
      :ok
    else
      {:error, "invalid tmpfs size: #{inspect(max_size)}"}
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
