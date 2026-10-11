> **SUPERSEDED — this is no longer the plan.** The setuid `tmptmpfs` design
> analysed below was abandoned and the setuid path has been deleted entirely.
> The helper now uses **unprivileged user namespaces** (`unshare(CLONE_NEWUSER)`
> + `CLONE_NEWNS)`) and requires **no changes to `nest` at all**. This document is
> retained only as the record of *why* the setuid approach cannot work. For the
> design that actually shipped, see [`notes/tmptmpfs-userns.md`](tmptmpfs-userns.md).

# Supporting setuid binaries and `tmptmpfs` tmpfs mounts inside the nest bwrap sandbox

A working note for the `nest` sandbox tool. Every claim below was verified against the
code (`path:line`) and, where noted, against a live sandbox (bwrap 0.9.0). `nest2` paths
are relative to the `nest` repo root; other paths are relative to the inkfish repo root.

## 1. Why this matters (the inkfish side)

- `Inkfish.Sandbox.TempFs.make_tempfs/1` (`lib/inkfish/sandbox/temp_fs.ex:11-13`) shells
  out to the helper as `tmptmpfs start -s <size>` and returns the mount path it prints.
- It is used by `Inkfish.Sandbox.Archive.safe_extract/3` (`lib/inkfish/sandbox/archive.ex:17`)
  before unpacking an uploaded archive.
- It is also used by `priv/scripts/upload_git_clone.sh`, which makes two `tmptmpfs start`
  calls: `CLONE_TMP` and `PERSIST_TMP` (`priv/scripts/upload_git_clone.sh:18,20`).
- Purpose of the tmpfs: a size-capped (`-s`), disposable scratch area so a crafted archive
  or repo cannot write outside it. `safe_extract` unpacks into the tmpfs, sanitizes
  symlinks, then copies the sanitized tree out to `target` (`lib/inkfish/sandbox/archive.ex:30`).

## 2. What `tmptmpfs` is and what it requires

- Rust helper at `support/tmptmpfs/` (`Cargo.toml`, `src/main.rs`, `install.sh`).
- `install.sh` copies the built binary to `/usr/local/bin/tmptmpfs` and does
  `chmod 04755` — i.e. **setuid root** (`support/tmptmpfs/install.sh:16-17`).
- `start` forks (`support/tmptmpfs/src/main.rs:160`). The child closes fds 0/1/2
  (`main.rs:175`, `close_fds/0` at `main.rs:151-157`) then runs
  `mount -t tmpfs -o size=<size> tmpfs /tmp/tmptmpfs/<pid>` (`main.rs:188-197`). The parent
  busy-loops polling `findmnt -J` (`main.rs:87-88`) every 100 ms until that path appears —
  **with no timeout** (`main.rs:164-170`). If the mount never appears, the parent never
  exits and never prints the path.
- `setuid_root/0` (`main.rs:233-240`) only calls `libc::setuid(0)` when `geteuid() == 0`;
  it does not itself acquire privilege. So the helper must already be euid 0 (via the
  setuid bit) **or** the calling process must otherwise hold the privilege to `mount(2)`.
- Therefore `tmptmpfs start` needs: euid 0 (honoured setuid) **and/or** `CAP_SYS_ADMIN` in
  the user namespace that owns the mount namespace, plus `mount` / `umount` / `findmnt` on
  `PATH` and a writable `/tmp/tmptmpfs`.

## 3. Why it cannot work in the current nest sandbox

Observed from inside a nest sandbox (bwrap 0.9.0), and traced to the code that produces it:

- **`/` is mounted `ro,nosuid,nodev`.** `/proc/self/mountinfo` shows `/` as
  `ro,nosuid,nodev,relatime`, which is bwrap's `--ro-bind / /`
  (`nest2/lib/nest/sandbox.ex:438`). A `nosuid` mount makes the kernel ignore the setuid
  bit on any binary on it, so `/usr/local/bin/tmptmpfs` never gains euid 0.
- **Host root is not mapped.** `stat /usr/local/bin/tmptmpfs` shows mode `4755` but owner
  `Uid: (65534/nobody)` — on the host the file is root-owned, so uid 0 is not mapped into
  the sandbox's user namespace and surfaces as the overflow uid (65534). Even a working
  setuid bit would target an unmapped uid, not root.
- **No capabilities are left, and `no_new_privs` is set.** bwrap is invoked with
  `--unshare-all` (`nest2/lib/nest/sandbox.ex:452`), which bwrap(1) documents as
  `--unshare-user-try --unshare-ipc --unshare-pid --unshare-net --unshare-uts
  --unshare-cgroup-try`. bwrap(1) states (under `--cap-drop`) that "By default no caps are
  left in the sandboxed process", and `/proc/self/status` inside the sandbox confirms
  `CapPrm = CapEff = CapBnd = 0`. So `mount -t tmpfs` returns `EPERM`.
- **bwrap's no-new-privs behaviour also defeats setuid.** bubblewrap's own README states it
  "uses `PR_SET_NO_NEW_PRIVS` to turn off setuid binaries"; the installed binary contains
  the string `prctl(PR_SET_NO_NEW_PRIVS) failed`, and `/proc/self/status` shows
  `NoNewPrivs: 1`. This is independent of the `nosuid` mount and, on its own, stops a
  setuid binary from elevating.
- **Consequence:** because `mount` fails in the child, the parent's `findmnt` loop
  (`support/tmptmpfs/src/main.rs:164-170`) never breaks, so inkfish's `System.cmd` blocks
  forever. This is what stalled inkfish's test suite. (inkfish now bounds the call — see §7.)

## 4. Why no `.nest` setting can fix this

The complete `.nest` schema as implemented by `Nest.ProjectConfig`
(`nest2/lib/nest/project_config.ex`):

- `[[mount]]` with `path` / `mode` (`"rw"` | `"tmp"`) / `create`
  (`project_config.ex:154-186`; `@modes` at `:57`).
- `[shell] background` (`project_config.ex:11-14`; `validate_shell/1` at `:124-134`).

Unknown keys are silently ignored: `validate/2` reads only `"mount"` and `"shell"`
(`project_config.ex:116-121`), and `validate_mount/2` reads only `path` / `mode` / `create`
(`project_config.ex:154-162`). `mode = "tmp"` means "bind a scratch **directory** under the
agent's scratch dir" (`project_config.ex:20-24`; `source_for/2` at `:282-285` returns
`<tmp_path>/project/<slug>`) — **not** a tmpfs. Both modes are emitted as plain `--bind`:
`append_project_binds/2` maps every mount to `["--bind", source, dest]`
(`nest2/lib/nest/sandbox.ex:492-503`). Mounts are honoured only in modes that already write
the symbolic `":workspace"` (`maybe_put_project_mounts/4` at `project_config.ex:249-259`,
gated by `workspace_writable?/1` at `:274`).

The complete set of bwrap flags nest can emit (`nest2/lib/nest/sandbox.ex`, assembled by
`build/5` at `:173-190`):

`--ro-bind`, `--bind`, `--dev-bind`, `--dev`, `--proc`, `--unshare-all`, `--unshare-net`,
`--share-net`, `--die-with-parent`, `--new-session`, `--chdir`
(built in `base_args/2` at `:434-458`, `hpu_args/1` at `:466-471`, `append_net_flag/2` at
`:473-474`, `append_workspace_bind/3` at `:479-489`, `append_project_binds/2` at `:492-503`,
`append_protected_binds/2` at `:507-517`, `append_write_binds/3` at `:519-531`,
`append_tmp_bind/3` at `:554-562`, `append_chdir/3` at `:564-566`).

There is **no** `--cap-add`, `--tmpfs`, `--uid` / `--gid`, `--privileged`,
device-passthrough config, or raw-flag escape hatch.

## 5. What nest would need to change

Ordered list of the changes required to support suid binaries and `tmptmpfs`:

1. **Grant `CAP_SYS_ADMIN`.** Add a caps field that emits `--cap-add CAP_SYS_ADMIN` —
   bwrap's flag for retaining a capability in the sandboxed process (bwrap(1): "Add the
   specified capability CAP … when running as privileged user"). Emit it where the other
   flags are built (`nest2/lib/nest/sandbox.ex:434-566`) and validate it in
   `Nest.Sandbox.Caps` (`nest2/lib/nest/sandbox/caps.ex`). Suggested shape: a `cap_add`
   list (e.g. `caps.privileges.cap_add`), or a boolean `privileged` shortcut.
2. **Add uid/gid mapping support.** Emit `--uid 0` / `--gid 0`; bwrap(1) requires
   `--unshare-user` for both (already present via `--unshare-all`'s `--unshare-user-try`).
   Note the deeper requirement: for a setuid-**root** target to resolve, host root must be
   *mapped* into the sandbox's user namespace — `--uid` / `--gid` set the sandbox uid, they
   do not by themselves map host uid 0.
3. **Do not mount the suid binary `nosuid`.** Today `/` is bound `ro,nosuid,nodev` via
   `--ro-bind` (`nest2/lib/nest/sandbox.ex:438`), which alone defeats setuid. This is a
   host/VM mount-option concern **outside nest** — call it out explicitly; nest cannot fix
   it with a flag on the read-only root bind.
4. **Decide how this interacts with `no_new_privs`.** Suid needs `no_new_privs` off;
   bubblewrap sets it by default (README). Turning it off is a deliberate security decision
   — see §6.
5. **`--tmpfs` is not a substitute.** bwrap's `--tmpfs DEST` (bwrap(1)) would let nest
   pre-mount a tmpfs at a path it chooses, but it does **not** by itself satisfy
   `tmptmpfs`, which mounts at its own `/tmp/tmptmpfs/<pid>` (`support/tmptmpfs/src/main.rs:190`)
   and therefore still needs `CAP_SYS_ADMIN` (or setuid root) inside the sandbox.

Proposed `.nest` opt-in shape:

```toml
[privileges]
cap_add = ["CAP_SYS_ADMIN"]
uid = 0
gid = 0
```

(`Nest.ProjectConfig` would need a matching schema — today `validate/2` ignores unknown
tables such as `[privileges]`.)

## 6. Security note

Granting `CAP_SYS_ADMIN` inside the sandbox is a significant widening. `CAP_SYS_ADMIN`
permits `mount(2)`, so the sandboxed process can mount filesystems — including over the
read-only binds the sandbox relies on — which can be used to defeat the sandbox's
read-only filesystem guarantees. It must be gated per-mode (only the modes that actually
need a tmpfs) and never on by default.

## 7. Interim mitigation in inkfish

- `Inkfish.Sandbox.TempFs` now bounds the helper: `make_tempfs/1` runs through `run/3`,
  which uses `Task.yield/2 || Task.shutdown/2, :brutal_kill` with a default 5 s timeout
  (`lib/inkfish/sandbox/temp_fs.ex:2,11-13,21-34`). A mount that never appears returns
  `{:error, "… timed out …"}` instead of hanging.
- `Archive.safe_extract/3` raises on that error (`lib/inkfish/sandbox/archive.ex:17-19`),
  so a failed mount produces a fast, legible failure.
- `priv/scripts/upload_git_clone.sh:18,20` wrap each `tmptmpfs start` in coreutils
  `timeout 10`; with `set -e` the script aborts quickly instead of hanging the caller.

## References

- inkfish: `lib/inkfish/sandbox/temp_fs.ex:2,11-13,21-34`
- inkfish: `lib/inkfish/sandbox/archive.ex:17-19,30`
- inkfish: `priv/scripts/upload_git_clone.sh:18,20`
- inkfish: `support/tmptmpfs/install.sh:16-17`
- inkfish: `support/tmptmpfs/src/main.rs:87-88,151-157,160,164-170,175,188-197,233-240`
- nest2: `lib/nest/sandbox.ex:173-190,434-458,466-471,473-474,479-489,492-503,507-517,519-531,554-562,564-566`
- nest2: `lib/nest/project_config.ex:11-14,20-24,57,116-121,124-134,154-186,249-259,274,282-285`
- nest2: `lib/nest/sandbox/caps.ex` (cap validation today: `net`, `fs`, `shell` only)
- bwrap(1) 0.9.0 (`/usr/share/man/man1/bwrap.1.gz`): `--unshare-all`, `--cap-add`,
  `--cap-drop` ("By default no caps are left in the sandboxed process"), `--uid`, `--gid`,
  `--tmpfs`
- bubblewrap `README.md` (`/usr/share/doc/bubblewrap/README.md.gz`): "bubblewrap uses
  `PR_SET_NO_NEW_PRIVS` to turn off setuid binaries"
- Observed in a live sandbox: `stat /usr/local/bin/tmptmpfs` (mode 4755, uid 65534);
  `/proc/self/mountinfo` (`/` = `ro,nosuid,nodev`); `/proc/self/status`
  (`NoNewPrivs: 1`, `CapPrm = CapEff = CapBnd = 0`)
