# Unprivileged user namespaces + size-limited tmpfs — operations note

Inkfish runs the commands that need a size-limited tmpfs — archive extraction
and the git clone — inside an **unprivileged user namespace plus a private
mount namespace**, created by util-linux `unshare(1)`. It needs **no setuid
bit**, **no helper binary**, and **no changes to `nest`**.

The `tmptmpfs` Rust helper this note used to document is gone: its whole job
was `unshare → mount tmpfs → exec`, which `unshare -Urm --propagation private`
does natively. (The filename is a leftover; the deployment/operations
counterpart to the superseded analysis in [`notes/nest-allow-suid.md`](nest-allow-suid.md)
and the work brief in [`notes/no-suid-tmpfs.md`](no-suid-tmpfs.md).)

All `path:line` references are relative to the inkfish repo root unless noted.

## 1. What runs now

`Inkfish.Sandbox.TempFs.run_in_tempfs/4` (`lib/inkfish/sandbox/temp_fs.ex:72-97`)
spawns exactly this argv (`:115-127`):

```
unshare -Urm --propagation private -- bash -c '<preamble>; exec "$@"' bash CMD ARGS...
```

- `-U` creates the unprivileged **user namespace** and `-r` maps the caller
  onto uid/gid 0 inside it, which is what makes mounting possible with no
  privilege on the host. `unshare` writes the map itself (including
  `setgroups=deny`), so there is no `uid_map`/`gid_map` handling in Inkfish.
- `-m` creates the **mount namespace** and `--propagation private` makes it
  private, so nothing mounted inside can reach the host mount table.
- `bash` runs the **preamble** (`lib/inkfish/sandbox/temp_fs.ex:141-157`), which:

  1. picks the anchor directory — `$TMPDIR` (falling back to `/tmp` when it is
     not absolute) joined with `inkfish-tmpfs`, canonicalised with
     `realpath -m` so the path below is absolute and slash-free;
  2. `mkdir -p`es that anchor and mounts a `mode=0700` tmpfs on it;
  3. creates the mount point **inside** that anchor tmpfs and mounts the
     size-capped tmpfs there: `mount -t tmpfs -o "size=$SIZE" tmpfs "$mount_path"`;
  4. exports the mount path as `$TMPFS`.

  Because the mount point lives inside the anchor tmpfs, it vanishes with the
  namespace: the only thing left on the host is the (empty) anchor directory
  itself.
- `exec "$@"` then replaces the shell with the caller's command, so the
  command's exit status and signals are what the port reports. The command is
  passed as `bash`'s positional parameters rather than spliced into the script
  text, so it is never re-parsed by the shell.

Properties: no setuid, no root, no helper binary, no background process, no
polling. The mounts, and the directories holding them, live only as long as the
command does.

`priv/scripts/upload_git_clone.sh` does the same thing for its two mounts: it
re-execs itself under one `unshare -Urm --propagation private`
(`priv/scripts/upload_git_clone.sh:11-14`, marked with `TMPTMPFS_ACTIVE` so the
inner run does not recurse), then mounts `CLONE_TMP` and `PERSIST_TMP` — capped
at `$CLONE_SIZE` and `$SUBMIT_SIZE` — inside its own anchor tmpfs
(`:16-32`). The caller no longer passes mount paths in; the script makes them.

The Elixir side runs that argv through a bounded port
(`lib/inkfish/sandbox/temp_fs.ex:175-209`), folding stdout and stderr together.
A non-zero exit becomes `{:error, reason}` carrying the output (`:220-242`,
`:256-261`); a timeout kills the whole process group (`:244-254`, `:274-288`).
`bin/0`
(`:99-108`) is the bare name `unshare`, resolved through `PATH`; a caller that
needs a specific binary passes `:bin` to `run_in_tempfs/4`.

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

That is why the preamble canonicalises the anchor with `realpath -m` before
building the mount path from it (`lib/inkfish/sandbox/temp_fs.ex:133-140`): a
`TMPDIR` that is relative or ends in a slash still yields an absolute,
slash-free mount path. The Elixir API documents the same contract (`:52-54`)
and the test asserts it (`test/inkfish/sandbox/temp_fs_test.exs:16-24`).

## 3. Why `tar --no-same-owner` is required

Inside the namespace only uid 0 is mapped, so `tar` sees euid 0, decides it
should restore the archive's ownership, and its `chown` to the archive's uid
hits an **unmapped** id. The extraction then fails with:

```
tar: ...: Cannot change ownership to uid 1000: Invalid argument
```

and `tar` exits non-zero, aborting the extraction. Hence the extraction script
passes `tar xvf "$INKFISH_ARCHIVE" --no-same-owner`
(`lib/inkfish/sandbox/archive.ex:192`; comment at `:176-186`).

The same hazard applies to anything else that restores metadata. The copy-out
must be `cp -r`, never `cp -a`/`cp -p`: the archive's ownership is not ours to
restore, and inside the namespace it is not even mapped
(`lib/inkfish/sandbox/archive.ex:204-211`, used at `:194` and `:209`).

## 4. Why a non-zero `tar` exit must be fatal

Extracting past the tmpfs size cap does not fail cleanly: `tar` writes the file
it can, leaves a **zero-byte** file for the one it could not finish, prints its
error, and exits **2**. A sanitizer run on that partial tree returns 0, so
without a guard the truncated tree would be copied out as if it were fine
(`lib/inkfish/sandbox/archive.ex:26-28`). The guard is `set -euo pipefail` at the
top of both generated scripts (`lib/inkfish/sandbox/archive.ex:190`, `:206`):
it makes the non-zero `tar` exit abort the whole script, before the copy-out.

This only helps if the caller checks the result. `safe_extract/3` returns
`:ok` or `{:error, reason}` rather than raising
(`lib/inkfish/sandbox/archive.ex:112-127`). `lib/inkfish/uploads.ex` checks it:
both `create_upload/1` and `create_fake_upload/1` match on `Upload.unpack/1`
(`lib/inkfish/uploads/upload.ex:216`) and turn a `{:error, reason}` into an
`{:error, changeset}` instead of reporting success, so a failed extraction can
no longer surface as `{:ok, upload}` with an empty `unpacked/` tree — exactly
the silent-success mode this change exists to remove. The reason itself is
deliberately carried into that changeset error (`lib/inkfish/uploads.ex:150-157`):
`unpack_error/2` appends `format_reason/1`, which passes a binary `reason`
through unchanged (server paths and all) and unwraps the tagged
missing-`elixir` reason to its own sentence. The users are computer science
students who can often understand and act on a technical error, so the real
reason is the intended user-facing message — not a leak to be plugged by
replacing it with a generic one. (Was tracked as work item 6 in
`notes/no-suid-tmpfs.md`.)

## 5. Requirements on the host

**`unshare(1)` from util-linux.** Everything here was verified against
**util-linux 2.39.3** (`unshare from util-linux 2.39.3`). The options used are
old and stable (`-U`, `-r`, `-m`, `--propagation`); 2.39 is simply the version
this deployment runs and tests against. `mount(8)`, `findmnt(1)` and
`realpath(1)` come from the same `util-linux`/`coreutils` packages and are
already required by the extraction scripts.

The namespace itself needs the host to allow **unprivileged user namespaces**:

- `kernel.unprivileged_userns_clone=1` (or a kernel where it is enabled by
  default).
- On Ubuntu 23.10+/24.04, `kernel.apparmor_restrict_unprivileged_userns`
  defaults to `1`. Set it to `0`, **or** install an AppArmor profile that
  permits `unshare` to create a user namespace. Without one of those the
  `unshare(2)` call is denied.
- Some container runtimes ship a seccomp profile that blocks `CLONE_NEWUSER`;
  `unshare` then cannot create its namespace regardless of the sysctls.

**Failure mode.** A denied or unsupported `unshare` is a loud, bounded failure,
never a hang: `unshare` prints `unshare: unshare failed: <reason>` on stderr and
exits non-zero, and a failing `mount` prints its own diagnostic. `TempFs` folds
stderr into the captured output and `exit_reason/2` returns it
(`lib/inkfish/sandbox/temp_fs.ex:220-242`, `:256-261`), so the caller sees
something like
`{:error, "exited 1: unshare: unshare failed: Operation not permitted"}`. The
call is also bounded by `:tempfs_timeout_ms`, and a timeout kills the process
group (`lib/inkfish/sandbox/temp_fs.ex:244-254`, `:274-288`).

Note what util-linux does and does not say: for a bad `size=` value the kernel
rejects the mount with `EINVAL`, and `mount(8)` prints one **generic** sentence
for that errno — `wrong fs type, bad option, bad superblock on tmpfs, ...` —
naming the mount point but neither the rejected option nor the errno. The old
helper named all three (`mount(tmpfs, <path>, size=1X) failed: Invalid
argument`), so this is a small loss of specificity in the mount-failure
diagnostic; the exit status and the mount point are still reported.

## 6. Installation

**Nothing to install, and nothing to build.** There is no helper binary any
more: `unshare` is a distribution package (`util-linux`), so there is no
install step, no Rust toolchain, and no artifact to keep in step with the
source.

There is also **no setuid anywhere in this path** — `unshare -Urm` gets the
privileges it needs from the user namespace, and the old `tmptmpfs` helper was
deliberately installed `0755` for the same reason. A setuid helper here would
be both unnecessary and a security regression.

A host that still has the old binary at `/usr/local/bin/tmptmpfs` should remove
it: Inkfish no longer looks for it, and it is broken anyway (it hangs, and it
expects privileges it should not have).

```bash
sudo rm -f /usr/local/bin/tmptmpfs
unshare --version   # util-linux, 2.39 assumed
```

## 7. Open risks / to verify

**(a) `elixir` must be reachable inside the namespace — UNVERIFIED.** The
sanitizer is Elixir: the script runs `"$INKFISH_ELIXIR" "$INKFISH_SANITIZE"
"$TMPFS"` inside the namespace (`lib/inkfish/sandbox/archive.ex:213-215`), where
`INKFISH_ELIXIR` comes from `elixir_bin/0` — `:elixir_bin` config or
`System.find_executable("elixir")` (`lib/inkfish/sandbox/archive.ex:64-70`). A
`mix release` does **not** put `elixir` on `PATH`, so a release deployment must
set `:elixir_bin` to a usable `elixir` (visible inside the namespace). This has
**not** been verified against a real release.

**(b) `priv/sandbox/*.exs` is format-checked.** `.formatter.exs` `inputs` covers
`*.{heex,ex,exs}`, `{config,lib,test}/**/*.{heex,ex,exs}`, `priv/*/seeds.exs`
and `priv/sandbox/*.exs` (`.formatter.exs:5-10`), so both
`priv/sandbox/sanitize_logic.exs` and `priv/sandbox/sanitize.exs` are covered
and `mix precommit` will format-check them.

**(c) Cost (measured).** About **260 ms per extraction** end to end, of which
about **150 ms is Erlang VM boot** for the sanitizer process, and about **0.6 ms
per relative symlink** (each relative link costs one `readlink -f` fork,
`priv/sandbox/sanitize_logic.exs:65`).

## References

- `lib/inkfish/sandbox/temp_fs.ex` — `:2-32` (moduledoc: the argv and why the
  mount is private), `:34-36` (defaults), `:38-46` (name/size validation),
  `:72-97` (`run_in_tempfs/4`), `:99-108` (`bin/0`), `:115-127` (argv),
  `:141-157` (preamble: anchor tmpfs, mount point, sized mount, export),
  `:175-209` (`run_bounded`), `:220-242`, `:256-261` (exit reason),
  `:274-288` (process-group kill)
- `priv/scripts/upload_git_clone.sh` — `:11-14` (re-exec under `unshare`),
  `:16-32` (the two sized mounts), `:37-38` (mount sanity check), `:82-155`
  (budget-aware checkout)
- `lib/inkfish/sandbox/archive.ex` — `:26-28` (non-zero `tar` exit is fatal),
  `:112-127` (`safe_extract/3`), `:176-192` (`--no-same-owner`, untar script),
  `:204-211` (`cp -r`, copy script), `:213-215` (sanitizer invocation),
  `:244-249` (`extraction_error/1`)
- `priv/sandbox/sanitize_logic.exs` — `:29-43` (raw `base` vs expanded walk),
  `:45-78` (link checks; `readlink -f` at `:65`, base comparison at `:69`)
- `priv/sandbox/sanitize.exs` — `:12` (requires the logic), `:14-30` (sentinel
  logger), `:32-39` (argv dispatch)
- `lib/inkfish/uploads.ex:150-157`, `:184-188` — `unpack_error/2` and
  `format_reason/1`
- `lib/inkfish/uploads/upload.ex:216` — `unpack/1`
- `config/test.exs:15-23` — `:tempfs_timeout_ms`, `:extract_timeout_ms`
- `.formatter.exs:5-10` — formatter `inputs`
- `test/inkfish/sandbox/temp_fs_test.exs:16-24` — exported-path contract
- `notes/nest-allow-suid.md` (superseded), `notes/no-suid-tmpfs.md` (work brief)
