# `tmptmpfs` on unprivileged user namespaces — operations note

The setuid-root `tmptmpfs` helper is gone. The helper is now an unprivileged
**scoped-exec wrapper** built on a user namespace plus a private mount namespace.
It needs **no setuid bit** and **no changes to `nest`**. This is the
deployment/operations counterpart to the now-superseded analysis in
[`notes/nest-allow-suid.md`](nest-allow-suid.md) and the work brief in
[`notes/no-suid-tmpfs.md`](no-suid-tmpfs.md).

All `path:line` references are relative to the inkfish repo root unless noted.

## 1. What the helper does now

CLI (`support/tmptmpfs/src/main.rs:3`, usage at `:23-34`):

```
tmptmpfs run [--tmpfs NAME=SIZE]... -- CMD [ARG...]
```

One invocation does all of the following, then `exec`s CMD:

1. **Parse argv** (`support/tmptmpfs/src/main.rs:90-137`): the only subcommand is
   `run`; `--tmpfs NAME=SIZE` is repeatable (and `--tmpfs=NAME=SIZE` is also
   accepted); `--` then separates the command. `NAME` must be a bare name (no
   `/`, not `.`/`..`, no whitespace or NUL) and `SIZE` must contain no comma or
   whitespace, so a SIZE cannot smuggle extra tmpfs mount options
   (`support/tmptmpfs/src/main.rs:139-165`). Duplicate NAMEs are rejected
   (`support/tmptmpfs/src/main.rs:238-240`).
2. **Capture the outer euid/egid before unsharing** (`support/tmptmpfs/src/main.rs:172-175`).
   This is required because after `CLONE_NEWUSER`, `geteuid()` reports the
   overflow uid until a map exists.
3. **`unshare(CLONE_NEWUSER)`** (`support/tmptmpfs/src/main.rs:178-180`).
4. **Map the caller onto uid/gid 0** (`support/tmptmpfs/src/main.rs:182-206`):
   deny `setgroups`, then write `0 <outer-uid> 1` to `/proc/self/uid_map` and the
   same shape to `gid_map`. The map is skipped only when `/proc/self/uid_map` is
   already non-empty (`support/tmptmpfs/src/main.rs:328-334`). When the caller is
   **already uid 0** this writes the identity map `0 0 1` — which is also the
   ordinary unprivileged "map my own uid" case. The write must not be skipped: an
   empty uid_map makes every inode created in the tmpfs fail with **EOVERFLOW**,
   so the first `mkdir` in the mount would fail with a confusing error. Writing
   the map up front also surfaces a kernel refusal (e.g. missing `CAP_SETFCAP`
   for a lower id of 0) as an explicit error here rather than as EOVERFLOW later.
5. **`unshare(CLONE_NEWNS)`** and make propagation private with
   `mount(NULL, "/", MS_REC|MS_PRIVATE)` (`support/tmptmpfs/src/main.rs:208-220`),
   so nothing it mounts can ever reach the host mount table.
6. **Mount a private anchor tmpfs** at `<tmpdir>/tmptmpfs` with `mode=0700`
   (`support/tmptmpfs/src/main.rs:222-234`), then, for each `--tmpfs`, create a
   directory under it and mount a `size=SIZE` tmpfs there
   (`support/tmptmpfs/src/main.rs:236-251`). Because the mount-point directories
   live inside the anchor tmpfs, they vanish with the namespace.
7. **Export each `NAME`** into the environment as the mount's **absolute path,
   with no trailing slash** (`support/tmptmpfs/src/main.rs:253-256`), then
   **`exec` CMD** (`support/tmptmpfs/src/main.rs:258-261`), so CMD's exit status
   and signals pass straight through.

Properties: no setuid, no root, no background process, no polling
(`support/tmptmpfs/src/main.rs:10-11`). The mounts, and the directories holding
them, live only as long as CMD (`support/tmptmpfs/src/main.rs:33-34`). Nothing is
left in the host mount table; the only thing that persists on the host is the
empty anchor directory itself, created once by `create_dir_all`
(`support/tmptmpfs/src/main.rs:228-230`, rationale at `:222-226`).

The Elixir side, `Inkfish.Sandbox.TempFs.run_in_tempfs/4`
(`lib/inkfish/sandbox/temp_fs.ex:49-68`), builds exactly that argv (`:55-62`) and
runs it through a bounded port (`:86-106`), folding stdout and stderr together
(`:92`). A non-zero exit becomes `{:error, reason}` carrying the output
(`:141-146`); a timeout kills the whole process group (`:134-139`, `:153-159`).
`bin/0` picks the binary — see §6.

## 2. Why the trailing-slash / absolute-path detail matters

The exported mount path is handed to the sanitizer, and the sanitizer compares a
**raw** base string against `readlink -f` output:

- `Inkfish.Sandbox.SanitizeLinks.sanitize_links!/1`
  (`priv/sandbox/sanitize_logic.exs:35-43`) computes `full = Path.expand(base)`
  (`:36`) and **walks the expanded path** (`:38`), but passes the **raw** `base`
  to `sanitize_link!/2` (`:40`).
- The relative-link check (`priv/sandbox/sanitize_logic.exs:64-72`) compares the
  result of `readlink -f path` (`:65-67`) against that raw `base`, keeping the
  link only when `targ == base` or `String.starts_with?(targ, base <> "/")`
  (`:69`). `readlink -f` always returns an **absolute, resolved** path.

So if `base` is relative, or ends in `/`, no resolved target can ever satisfy
that comparison and **every** in-tree relative symlink is deleted. Measured: **9
removals instead of 5**.

That is exactly why `mount_root()` guarantees the exported path is absolute and
slash-free: it falls back to `/tmp` when `TMPDIR` is relative, and strips
trailing components/slashes via `.components().collect()`
(`support/tmptmpfs/src/main.rs:344-357`, rationale at `:337-343`). The Elixir API
documents the same contract (`lib/inkfish/sandbox/temp_fs.ex:29-31`) and the test
asserts it (`test/inkfish/sandbox/temp_fs_test.exs:16-24`).

## 3. Why `tar --no-same-owner` is required

Inside the namespace only uid 0 is mapped, so `tar` sees euid 0, decides it
should restore the archive's ownership, and its `chown` to the archive's uid
hits an **unmapped** id. The extraction then fails with:

```
tar: ...: Cannot change ownership to uid 1000: Invalid argument
```

and `tar` exits non-zero, aborting the extraction. Hence the extraction script
passes `tar xvf "$INKFISH_ARCHIVE" --no-same-owner`
(`lib/inkfish/sandbox/archive.ex:105`; comment at `:89-92`).

The same hazard applies to anything else that restores metadata. The copy-out
must be `cp -r`, never `cp -a`/`cp -p`: the archive's ownership is not ours to
restore, and inside the namespace it is not even mapped
(`lib/inkfish/sandbox/archive.ex:111-116`, used at `:107` and `:122`).

## 4. Why a non-zero `tar` exit must be fatal

Extracting past the tmpfs size cap does not fail cleanly: `tar` writes the file
it can, leaves a **zero-byte** file for the one it could not finish, prints its
error, and exits **2**. A sanitizer run on that partial tree returns 0, so
without a guard the truncated tree would be copied out as if it were fine
(`lib/inkfish/sandbox/archive.ex:26-28`). The guard is `set -euo pipefail` at the
top of both generated scripts (`lib/inkfish/sandbox/archive.ex:103`, `:119`):
it makes the non-zero `tar` exit abort the whole script, before the copy-out.

This only helps if the caller checks the result. `safe_extract/3` now returns
`:ok` or `{:error, reason}` rather than raising
(`lib/inkfish/sandbox/archive.ex:38-56`). `lib/inkfish/uploads.ex` checks it:
both `create_upload/1` (`lib/inkfish/uploads.ex:60-88`) and
`create_fake_upload/1` (`lib/inkfish/uploads.ex:105-131`) match on
`Upload.unpack/1` (`lib/inkfish/uploads/upload.ex:188-190`) and turn a
`{:error, reason}` into an `{:error, changeset}` instead of reporting success,
so a failed extraction can no longer surface as `{:ok, upload}` with an empty
`unpacked/` tree — exactly the silent-success mode this change exists to
remove. The reason itself is deliberately carried into that changeset error:
`unpack_error/2` appends `format_reason/1`, which passes a binary `reason`
through unchanged (server paths and all) and unwraps the tagged
missing-`elixir` reason to its own sentence. The users are computer science
students who can often understand and act on a technical error, so the real
reason is the intended user-facing message — not a leak to be plugged by
replacing it with a generic one. (Was tracked as work item 6 in
`notes/no-suid-tmpfs.md`.)

## 5. Requirements on the host

The helper needs to be able to create an **unprivileged user namespace**:

- `kernel.unprivileged_userns_clone=1` (or a kernel where it is enabled by
  default).
- On Ubuntu 23.10+/24.04, `kernel.apparmor_restrict_unprivileged_userns`
  defaults to `1`. Set it to `0`, **or** install an AppArmor profile that permits
  this binary to create a user namespace. Without one of those the
  `unshare(CLONE_NEWUSER)` call is denied.
- Some container runtimes ship a seccomp profile that blocks `CLONE_NEWUSER`; the
  helper then cannot create its namespace regardless of the sysctls.

**Failure mode.** A denied or unsupported `unshare` is a loud, bounded failure,
never a hang: the helper prints `tmptmpfs: unshare(CLONE_NEWUSER) failed: <errno>`
and exits non-zero (`support/tmptmpfs/src/main.rs:178-180`; the mount-namespace
and mount failures behave the same, `:210-220`, `:264-306`). `TempFs` folds
stderr into the captured output (`lib/inkfish/sandbox/temp_fs.ex:92`) and
`exit_reason/2` returns it (`:141-146`), so the caller sees something like
`{:error, "exited 1: tmptmpfs: unshare(CLONE_NEWUSER) failed: ..."}`. The call is
also bounded by `:tempfs_timeout_ms`, and a timeout kills the process group
(`lib/inkfish/sandbox/temp_fs.ex:97`, `:134-139`).

## 6. Installation

`support/tmptmpfs/install.sh` now does a plain install: copy the built binary to
`/usr/local/bin/tmptmpfs` and `chmod 0755` (`support/tmptmpfs/install.sh:16-19`).
The binary must **never** be installed setuid root — the helper gets its
privileges from the user namespace, and a setuid helper would be both unnecessary
and a security regression.

Replacing an existing install matters: the old setuid binary may still be present
at `/usr/local/bin/tmptmpfs`, and it is broken (it hangs, and it expects
privileges it no longer should have). Re-run `install.sh` (or otherwise overwrite
the path) to replace it.

`TempFs.bin/0` (`lib/inkfish/sandbox/temp_fs.ex:80-84`) resolves the helper as
`:tmptmpfs_bin` config first, then the `TMPTMPFS_BIN` environment variable, then
the bare name `tmptmpfs` on `PATH`. Explicit configuration wins over `PATH`
precisely so a stale helper earlier on `PATH` cannot be picked up by accident.
The test config relies on this and says why (`config/test.exs:19-24`). Shell
callers share the same override through `"${TMPTMPFS_BIN:-tmptmpfs}"`
(`lib/inkfish/sandbox/temp_fs.ex:76-78`).

## 7. Open risks / to verify

**(a) `elixir` must be reachable inside the namespace — UNVERIFIED.** The
sanitizer is Elixir: the script runs `"$INKFISH_ELIXIR" "$INKFISH_SANITIZE"
"$TMPFS"` inside the namespace (`lib/inkfish/sandbox/archive.ex:126-128`), where
`INKFISH_ELIXIR` comes from `elixir_bin/0` — `:elixir_bin` config or
`System.find_executable("elixir")` (`lib/inkfish/sandbox/archive.ex:166-172`). A
`mix release` does **not** put `elixir` on `PATH`, so a release deployment must
set `:elixir_bin` to a usable `elixir` (visible inside the namespace). This has
**not** been verified against a real release.

**(b) `priv/sandbox/*.exs` is format-checked.** `.formatter.exs` `inputs` now
covers `*.{heex,ex,exs}`, `{config,lib,test}/**/*.{heex,ex,exs}`,
`priv/*/seeds.exs` and `priv/sandbox/*.exs` (`.formatter.exs:5-10`), so both
`priv/sandbox/sanitize_logic.exs` and `priv/sandbox/sanitize.exs` are covered
and `mix precommit` will format-check them.

**(c) Cost (measured).** About **260 ms per extraction** end to end, of which
about **150 ms is Erlang VM boot** for the sanitizer process, and about **0.6 ms
per relative symlink** (each relative link costs one `readlink -f` fork,
`priv/sandbox/sanitize_logic.exs:65`).

## References

- `support/tmptmpfs/src/main.rs` — `:1-11` (module doc: no setuid/root/polling),
  `:23-34` (usage), `:90-137` (arg parse), `:139-165` (NAME/SIZE validation),
  `:171-206` (userns + uid/gid map; `ids_are_mapped` at `:328-334`), `:208-220`
  (mountns + `MS_REC|MS_PRIVATE`), `:222-256` (anchor tmpfs, per-mount tmpfs,
  env export), `:258-261` (exec), `:264-306` (`mount_tmpfs`), `:308-326`
  (`write_proc`), `:337-357` (`mount_root`)
- `support/tmptmpfs/Cargo.toml` — the only dependency is `libc`
- `support/tmptmpfs/install.sh:16-19` — plain `chmod 0755`, no setuid
- `lib/inkfish/sandbox/temp_fs.ex` — `:20-23` (defaults), `:29-31` (path
  contract), `:49-68` (`run_in_tempfs/4`), `:80-84` (`bin/0`), `:86-106`
  (`run_bounded`), `:134-146` (timeout / exit reason), `:153-159`
  (process-group kill)
- `lib/inkfish/sandbox/archive.ex` — `:33-36` (non-zero `tar` exit is fatal),
  `:38-56` (`safe_extract/3`), `:102-121` (`--no-same-owner`, untar script),
  `:124-137` (`cp -r`, copy script), `:139-154` (sanitizer invocation + env),
  `:156-168` (warning forwarding), `:170-199` (`extraction_error/1`,
  `timeout_ms/0`, `priv/1`, `elixir_bin/0`)
- `priv/sandbox/sanitize_logic.exs` — `:29-43` (raw `base` vs expanded walk),
  `:45-78` (link checks; `readlink -f` at `:65`, base comparison at `:69`)
- `priv/sandbox/sanitize.exs` — `:12` (requires the logic), `:14-29` (sentinel
  logger), `:32-39` (argv dispatch)
- `lib/inkfish/uploads.ex:60`, `:105` — callers of `Upload.unpack/1` (result
  checked)
- `lib/inkfish/uploads/upload.ex:188-190` — `unpack/1`
- `config/test.exs:16-30` — `:tempfs_timeout_ms`, `:extract_timeout_ms`,
  `:tmptmpfs_bin`
- `.formatter.exs:5-10` — formatter `inputs`
- `test/inkfish/sandbox/temp_fs_test.exs:16-24` — exported-path contract
- `notes/nest-allow-suid.md` (superseded), `notes/no-suid-tmpfs.md` (work brief)
