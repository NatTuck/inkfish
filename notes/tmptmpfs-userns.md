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

`Inkfish.Sandbox.TempFs.unshare_argv/3`
(`lib/inkfish/sandbox/temp_fs.ex:94-118`) is the **only** place that knows this
argv (`:211-232`):

```
unshare -Urm --propagation private -- bash -c '<preamble>; exec "$@"' bash CMD ARGS...
```

- `-U` creates the unprivileged **user namespace** and `-r` maps the caller
  onto uid/gid 0 inside it, which is what makes mounting possible with no
  privilege on the host. `unshare` writes the map itself (including
  `setgroups=deny`), so there is no `uid_map`/`gid_map` handling in Inkfish.
- `-m` creates the **mount namespace** and `--propagation private` makes it
  private, so nothing mounted inside can reach the host mount table.
- `bash` runs the **preamble** (`lib/inkfish/sandbox/temp_fs.ex:234-269`), which:

  1. picks the anchor directory — `$TMPDIR` (falling back to `/tmp` when it is
     not absolute) joined with `inkfish-tmpfs`, canonicalised with
     `realpath -m` so the paths below are absolute and slash-free;
  2. `mkdir -p`es that anchor and mounts a `mode=0700` tmpfs on it;
  3. for **each requested mount** — one `{name, size}` pair per entry — creates
     the mount point **inside** that anchor tmpfs and mounts the size-capped
     tmpfs there: `mount -t tmpfs -o "size=$SIZE" tmpfs "$mount_path"`;
  4. exports each mount path under its own name: `$TMPFS` for the archive
     extraction, `$CLONE_TMP`/`$PERSIST_TMP` for the git clone.

  Because the mount points live inside the anchor tmpfs, they vanish with the
  namespace: the only thing left on the host is the (empty) anchor directory
  itself.
- `exec "$@"` then replaces the shell with the caller's command, so the
  command's exit status and signals are what the port reports. The command is
  passed as `bash`'s positional parameters rather than spliced into the script
  text, so it is never re-parsed by the shell.

Properties: no setuid, no root, no helper binary, no background process, no
polling. The mounts, and the directories holding them, live only as long as the
command does.

Both callers go through that one argv. `run_in_tempfs/4` (`:120-150`) spawns it
through a bounded port; `run_in_one_tempfs/4` (`:152-165`) is the single-mount
convenience the extraction uses, and it is the one that names the mount
`TMPFS`. `Inkfish.Uploads.Git.start_clone/1` builds the same argv for its two
mounts and hands it to `Inkfish.Ittys`, which keeps its own supervision and
streaming — the argv's first element is the resolved absolute path of
`unshare`, because Ittys `execve(2)`s the argv with no shell and `execve(2)`
does not search `PATH` (`:94-118`).

`priv/scripts/upload_git_clone.sh` is a plain script as a result. It used to
re-exec itself under one `unshare -Urm --propagation private` and mount
`CLONE_TMP` and `PERSIST_TMP` itself, with a recursion marker to stop the
re-exec from looping; the mounts are made for it now, so it opens by asserting
they exist (`priv/scripts/upload_git_clone.sh:15-16`), which is what catches
the script being run without the sandbox. Everything below that is unchanged.

The mount name and the size are both checked **in Elixir**, before anything is
spawned (`lib/inkfish/sandbox/temp_fs.ex:271-296`): the name against
`@name_format` (`:66`) and the size against `@size_format` (`:83`), each
rejection naming the offending value. Neither can therefore carry shell syntax
or a second mount option into the preamble, and the preamble does no validation
of its own.

The Elixir side runs that argv through a bounded port
(`lib/inkfish/sandbox/temp_fs.ex:298-332`), folding stdout and stderr together.
A non-zero exit becomes `{:error, reason}` carrying the output (`:343-364`,
`:379-384`); a timeout kills the whole process group (`:366-377`, `:397-409`).
`bin/0` (`:174-176`) is the bare name `unshare`; `unshare_bin/0` (`:185-187`)
resolves it through `PATH`, which is what `Inkfish.Application` checks once at
boot (`lib/inkfish/application.ex:81-91`), and a caller that needs a specific
binary passes `:bin` to `run_in_tempfs/4` (`:199-209`).

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
building the mount paths from it (`lib/inkfish/sandbox/temp_fs.ex:236-263`): a
`TMPDIR` that is relative or ends in a slash still yields absolute, slash-free
mount paths. The Elixir API documents the same contract (`:120-129`) and the
test asserts it (`test/inkfish/sandbox/temp_fs_test.exs:8-25`).

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
(`lib/inkfish/sandbox/archive.ex:200-211`, used at `:194` and `:209`).

## 4. Why a non-zero `tar` exit must be fatal

Extracting past the tmpfs size cap does not fail cleanly: `tar` writes the file
it can, leaves a **zero-byte** file for the one it could not finish, prints its
error, and exits **2**. A sanitizer run on that partial tree returns 0, so
without a guard the truncated tree would be copied out as if it were fine
(`lib/inkfish/sandbox/archive.ex:105-110`). The guard is `set -euo pipefail` at
the top of both generated scripts (`lib/inkfish/sandbox/archive.ex:190`,
`:206`): it makes the non-zero `tar` exit abort the whole script, before the
copy-out.

This only helps if the caller checks the result. `safe_extract/3` returns
`:ok` or `{:error, reason}` rather than raising
(`lib/inkfish/sandbox/archive.ex:112-127`). `lib/inkfish/uploads.ex` checks it:
both `create_upload/1` and `create_fake_upload/1` match on `Upload.unpack/1`
(`lib/inkfish/uploads/upload.ex:216`) and turn a `{:error, reason}` into an
`{:error, changeset}` instead of reporting success, so a failed extraction can
no longer surface as `{:ok, upload}` with an empty `unpacked/` tree — exactly
the silent-success mode this change exists to remove. The reason itself is
deliberately carried into that changeset error (`lib/inkfish/uploads.ex:150-157`):
`unpack_error/2` appends `format_reason/1` (`:184`), which passes a binary
`reason` through unchanged (server paths and all) and unwraps the tagged
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
(`lib/inkfish/sandbox/temp_fs.ex:343-364`, `:379-384`), so the caller sees
something like
`{:error, "exited 1: unshare: unshare failed: Operation not permitted"}`. The
call is also bounded by `:tempfs_timeout_ms`, and a timeout kills the process
group (`lib/inkfish/sandbox/temp_fs.ex:366-377`, `:397-409`).

Note what util-linux does and does not say: for a bad `size=` value the kernel
rejects the mount with `EINVAL`, and `mount(8)` prints one **generic** sentence
for that errno — `wrong fs type, bad option, bad superblock on tmpfs, ...` —
naming the mount point but neither the rejected option nor the errno. The old
helper named all three (`mount(tmpfs, <path>, size=1X) failed: Invalid
argument`), so a kernel refusal still says less than that; a size the kernel
would refuse is therefore rejected by `TempFs` first, with a message that quotes
it (`lib/inkfish/sandbox/temp_fs.ex:271-296`). The exit status and the mount
point are reported either way.

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

- `lib/inkfish/sandbox/temp_fs.ex` — `:2-52` (moduledoc: the argv, one primitive
  for both callers, why the mount is private), `:54-55` (defaults), `:59`
  (the `TMPFS` mount name), `:66`/`:83` (name and size formats),
  `:85-93` (missing-`unshare` log message), `:94-118` (`unshare_argv/3`),
  `:120-150` (`run_in_tempfs/4`), `:152-165` (`run_in_one_tempfs/4`),
  `:174-176` (`bin/0`), `:185-187` (`unshare_bin/0`), `:199-209` (binary
  resolution, `:bin`), `:211-232` (argv), `:234-269` (preamble: anchor tmpfs,
  one mount point + sized mount + export per mount, `exec "$@"`),
  `:271-296` (name/size validation), `:298-332` (`run_bounded/4`), `:343-364`
  and `:379-384` (exit reason), `:366-377` and `:397-409` (process-group kill)
- `priv/scripts/upload_git_clone.sh` — `:15-16` (mount sanity check; the script
  is otherwise plain, the mounts are made for it), `:60` (`MARGIN_KB`),
  `:65-135` (budget-aware checkout), `:145-165` (tar + copy-out)
- `lib/inkfish/sandbox/archive.ex` — `:105-110` (non-zero `tar` exit is fatal),
  `:112-127` (`safe_extract/3`), `:176-192` (`--no-same-owner`, untar script),
  `:200-211` (`cp -r`, copy script), `:213-215` (sanitizer invocation),
  `:244-250` (`extraction_error/1`)
- `lib/inkfish/uploads/git.ex` — `start_clone/1` (builds the two-mount argv and
  hands it to `Inkfish.Ittys`)
- `lib/inkfish/application.ex:81-91` — the boot check that `unshare` resolves
- `priv/sandbox/sanitize_logic.exs` — `:29-43` (raw `base` vs expanded walk),
  `:45-78` (link checks; `readlink -f` at `:65`, base comparison at `:69`)
- `priv/sandbox/sanitize.exs` — `:12` (requires the logic), `:14-30` (sentinel
  logger), `:32-39` (argv dispatch)
- `lib/inkfish/uploads.ex:150-157`, `:184-188` — `unpack_error/2` and
  `format_reason/1`
- `lib/inkfish/uploads/upload.ex:216` — `unpack/1`
- `config/test.exs:15-23` — `:tempfs_timeout_ms`, `:extract_timeout_ms`
- `.formatter.exs:5-10` — formatter `inputs`
- `test/inkfish/sandbox/temp_fs_test.exs:8-25` — exported-path contract
- `notes/nest-allow-suid.md` (superseded), `notes/no-suid-tmpfs.md` (work brief)
