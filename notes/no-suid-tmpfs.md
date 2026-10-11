The full `safe_extract` shape now works end to end inside a private userns+mountns:

- tmpfs mounted at the requested size (10M)
- `tar xzf ... --no-same-owner` extracted successfully (the fix for the unmapped-uid chown failure)
- **Elixir ran inside the namespace** and read the tree (`symlinks=["tree/escape"]`) — so the sanitizer can stay in Elixir, preserving fidelity
- `cp -r` out to a host-visible target worked
- content correct, symlink preserved (so the sanitizer has something to act on)
- ownership on the host is 1000:1000 (the caller), not root

So the redesign is feasible with two concrete requirements discovered:
1. The helper must be a scoped-exec wrapper (mount and run), not a path provider.
2. Extraction inside must pass `--no-same-owner` (or equivalent) because the archive's uids aren't mapped in the single-uid userns; otherwise tar fails with `Cannot change ownership to uid 1000: Invalid argument`.

That second point is a genuinely non-obvious gotcha that would burn time. Excellent brief material.

Now let me write the brief for the Inkfish-editing agent team.

Structure of the brief:

**0. Objective** (one paragraph)
**1. The constraint that determines the design** (visibility → scoped exec)
**2. Verified reference shape** (the exact commands that work, including --no-same-owner)
**3. Work items** (per file, with what to change)
**4. The one decision to bring back, with a recommendation** (sanitizer placement)
**5. Invariants that must not break** (fidelity rules)
**6. Failure handling (must be part of this, not deferred)** — the current bugs
**7. Environment requirements + fallback matrix**
**8. Acceptance criteria / how to verify**
**9. Explicit non-goals / things not to propose**
**10. Open questions to bring back**

I should make it paste-ready, since the user will hand it to a team.

Let me get the specifics right:
- `lib/inkfish/sandbox/temp_fs.ex:11-13` — make_tempfs
- `lib/inkfish/sandbox/temp_fs.ex:21-34` — run/3 (leaks the process)
- `lib/inkfish/sandbox/archive.ex:12-34` — safe_extract (mount → untar → sanitize_links! → cp -r; `raise` at :19)
- `lib/inkfish/sandbox/archive.ex:38-81,98-107` — sanitize_links!/sanitize_link!
- `lib/inkfish/sandbox.ex:13-15` — dead make_tempfs delegation
- `lib/inkfish/sandbox.ex:22-24` — extract_archive
- `lib/inkfish/uploads/upload.ex:188-190` — unpack
- `lib/inkfish/uploads.ex:65` — create_upload discards unpack result; `:100` create_fake_upload
- `priv/scripts/upload_git_clone.sh:18,20` — two tmptmpfs start calls (CLONE_TMP 100m, PERSIST_TMP 5m); `:114-123` df budget
- `support/tmptmpfs/install.sh:16-17` — chmod 04755
- `support/tmptmpfs/src/main.rs` — the helper; `:164-170` unbounded findmnt poll; `:126` clean panic; `:188-197` mount; `:233-240` setuid_root
- `test/inkfish/sandbox/temp_fs_test.exs` — the new test file (3 tests on run/3)
- `config/test.exs:17` — 2s tempfs timeout

Tests to add (propose, don't land without approval):
- cap: mount is tmpfs, size matches, ENOSPC past it
- failure path: helper fails → {:error}, safe_extract raises
- cap-hit end-to-end using the unused `test/scripts/data/twenty.tar.gz`
- df-budget branch in the git script
- don't relax git_clone_script_test.exs:46,55 or clone_channel_test.exs:39

Non-goals:
- no :erl_tar (explicitly ruled out by the user: can't handle their archives, plus bug concerns)
- no plain directory / PATH shim / test-only branch
- no changes to test assertions without explicit user approval (inkfish AGENTS.md:241)
- don't touch nest
- don't reimplement the sanitizer in shell as a shortcut

Environment requirements:
- unprivileged userns creation required: `kernel.unprivileged_userns_clone=1` (or kernel default-enabled) and `kernel.apparmor_restrict_unprivileged_userns=0` or an AppArmor profile for the binary. Measured here: clone=1, apparmor_restrict=0, label unconfined.
- Ubuntu 23.10+/24.04 default restrict=1 → needs a profile; team must produce or document.
- container seccomp may block CLONE_NEWUSER.
- Decide: fail loudly vs keep a setuid fallback. Recommend fail loudly + document (the user wants the setuid binary gone).

Also the "already uid 0" wrinkle: if invoked from an environment where uid is already 0, the uid_map write has lower_first==0 which needs CAP_SETFCAP; handle "already root, don't remap".

Also: two mounts in the git script → one wrapper invocation with two mounts.

Also: keep the per-call size cap (each invocation gets its own ns).

Also worth noting: the helper no longer needs to be Rust necessarily — but a Rust implementation using libc unshare+mount is fine and gives better error handling. Team evaluates shell (`unshare(1)`) vs Rust. Note `unshare(1)` is util-linux and may not be present on all hosts — whereas a Rust binary using `unshare(2)` directly has no such dependency. That's a real argument for keeping Rust. Good point to include.

Let me write it now. It should be comprehensive but scannable. I'll present it as a paste-ready brief.

I should also offer: I can run this as work orders to a programmer minion team, or the user hands it to their own team.

Let me write.

---

Verified end to end. The whole `safe_extract` shape works inside a private userns+mountns — **including the Elixir sanitizer**, so fidelity is preserved. And I found a non-obvious gotcha that would otherwise burn a day.

---

# Brief: replace the setuid `tmptmpfs` binary with unprivileged namespaces

## 0. Objective

Remove the setuid-root `tmptmpfs` helper from Inkfish and replace it with an unprivileged mechanism built on unprivileged user namespaces + a private mount namespace. The size cap must remain **kernel-enforced** by tmpfs `size=`. Target end state: no setuid binary, and the tmpfs-dependent tests pass **unmodified** inside a bwrap sandbox (which is what motivated this).

## 1. The constraint that determines the whole design

A tmpfs mounted inside a namespace the helper creates is **invisible to the caller**. So the helper cannot keep its current contract ("mount, print a path, let the caller use it"). It must become **scoped execution**: mount inside its own namespace, then run the caller's command there.

`tmptmpfs run -s 10M -- <command>…` → create userns → map caller→root inside → create mountns → mount capped tmpfs → exec. Mount dies with the namespace.

Corollary: every call site's work must move inside the wrapper. Don't try to make the BEAM enter the namespace — `setns` only affects the calling thread and BEAM is heavily threaded.

## 2. Verified reference shape

This is measured, not proposed. Run it as the template:

```bash
unshare -Urm --propagation private bash -c '
  set -e
  export T=/path/to/mountpoint
  mkdir -p "$T"
  mount -t tmpfs -o size=10M tmpfs "$T"
  tar xzf /path/to/archive.tgz -C "$T" --no-same-owner      # <-- REQUIRED, see below
  elixir /path/to/sanitize.exs "$T"                          # Elixir runs fine inside
  cp -r "$T/." /path/to/target/                              # copy-out lands on the real fs
'
```

Observed: `findmnt` reports `tmpfs 10M`; `dd` stops at 10,481,664 bytes with `ENOSPC`; Elixir inside the namespace read the tree and saw the escaping symlink; `cp -r` out worked; files on the host are owned by the caller (`1000:1000`); the mount is gone when the namespace exits.

**The gotcha, and it is the important one:** without `--no-same-owner`, extraction **fails**:

```
tar: tree/sub/file.txt: Cannot change ownership to uid 1000, gid 1000: Invalid argument
tar: Exiting with failure status due to previous errors
```

Because inside the namespace only uid 0 is mapped (to the caller), `tar` sees euid 0, decides it should restore the archive's ownership, and `chown(1000)` hits an unmapped uid. On the host the setuid helper really is root, so this never happened. **Everything that restores ownership or metadata must be handled explicitly** — `tar --no-same-owner`, and audit `cp` (`-r` is fine; `-a`/`-p` are not).

## 3. Work items

| # | Where | What |
|---|---|---|
| 1 | `support/tmptmpfs/` | Replace the helper: drop `setuid_root/0` and the `chmod 04755` in `install.sh:16-17`. New binary does `unshare(CLONE_NEWUSER)` → write uid/gid maps (skip remapping if already uid 0) → `unshare(CLONE_NEWNS)` → mount → exec. Keep it Rust (no dependency on util-linux `unshare(1)` being installed); the shell form above is the reference, not necessarily the implementation. |
| 2 | `lib/inkfish/sandbox/temp_fs.ex:11-13` | New API. `make_tempfs/1` (returns a path) cannot survive. Propose `with_tempfs(max_size, fn tmpfs_path -> ... end)` or `run_in_tempfs(max_size, cmd, args)`. Evaluate both and report. |
| 3 | `lib/inkfish/sandbox/archive.ex:12-34` | `safe_extract/3`'s four steps (mount → `untar` → `sanitize_links!` → `cp -r tdir/. target`) must all run inside the wrapper. See §4 for the one decision. |
| 4 | `priv/scripts/upload_git_clone.sh:18,20` | Nearly free: run the whole script under one wrapper invocation, with **two** mounts inside it (`CLONE_TMP` 100m, `PERSIST_TMP` 5m) — both must be visible to the script. |
| 5 | `lib/inkfish/sandbox.ex:13-15` | Delete the dead `make_tempfs/1` delegation (no callers anywhere). |
| 6 | `lib/inkfish/uploads.ex:65` and `:100` | **Stop discarding `Upload.unpack/1`'s result.** Today a failed extraction returns `{:ok, upload}` with an empty `unpacked/` — silent data loss instead of a rejection. This is a real production bug and must be fixed for the new mechanism to be trustworthy. |
| 7 | `lib/inkfish/sandbox/temp_fs.ex:21-34` | Kill the **process group** on timeout, not just the BEAM task. Today `Task.shutdown(:brutal_kill)` leaks the helper's forked child, which keeps spinning and holds the caller's stdout — piped runs never see EOF. |
| 8 | Helper internals | Bound every wait and exit non-zero with a diagnostic. `src/main.rs:164-170` polls `findmnt` **with no timeout** — that's the hang that stalled the suite, and it fires in production too (any `nosuid` mount, `NoNewPrivs=yes` systemd unit, or cap-dropping container). Also `:126` `clean` panics on non-numeric entries, and every failed `start` leaks a `/tmp/tmptmpfs/<pid>` dir. The scoped-exec design removes the poll and the leaked mounts entirely. |

## 4. The one decision to bring back (with a recommendation)

**Where does `sanitize_links!` live?** Three options:

- **(i) Reimplement it in shell inside the wrapper** → the Elixir sanitizer stops being the production path and becomes test-only. The tests would keep passing while production runs different logic. **Reject unless the user explicitly approves it.**
- **(ii) Keep the Elixir sanitizer and invoke it from inside the wrapper** (`elixir sanitize.exs "$T"`). Production runs the same code, tests keep their meaning. Verified feasible — Elixir starts and reads the tree inside the namespace. Cost: an Elixir VM start per extraction.
- **(iii) Keep the extraction in Elixir and have the BEAM run inside the namespace** — not viable (`setns` is per-thread).

**Recommendation: (ii).** Bring back the measured cost of the extra VM start.

## 5. Invariants that must not break

- The cap stays **kernel-enforced**, per call, at the requested size. One shared mount for several sizes is not acceptable.
- Production must call the same sanitization logic the tests exercise (§4).
- **No test-only branches**, no PATH shim, no fallback to a plain directory, no silent success.
- `test/inkfish/uploads/git_clone_script_test.exs:46,55` must keep asserting the *specific* messages (`"Invalid path in repo"`, `"transport 'file' not allowed"`) — never relaxed to `code != 0`, which passes today in a broken environment for the wrong reason.
- `test/inkfish_web/channels/clone_channel_test.exs:39` must keep asserting `%{status: "normal"}`, not merely that a frame arrived.
- **Do not change what any test asserts without explicit user approval** (inkfish `AGENTS.md:241`).

## 6. Tests to add (propose them, don't silently land them)

1. `make_tempfs`/`with_tempfs` yields a real tmpfs of the requested size — `findmnt -T` says `tmpfs`, and writing past `-s` fails `ENOSPC`. Repeat for two different sizes (this is what catches "sizes transposed" — currently `100m` and `5m` are indistinguishable to the suite).
2. The cap-hit path end to end, using the already-present but **unreferenced** `test/scripts/data/twenty.tar.gz` (20,971,520 B uncompressed from 20,497 B) — and assert it *fails loudly*, not `{:ok, upload}` with an empty tree.
3. The failure path: a helper that can't mount → `{:error, …}` in bounded time, plus `assert_raise` for `archive.ex:19`.
4. The `df`-budget branch (`upload_git_clone.sh:111-123`): a blob larger than `SUBMIT_SIZE − 512 KB` must produce `.csum` and print `replaced files: 1`. Uncapped, that branch is dead code and nothing notices.

## 7. Environment requirements and the fallback question

The new mechanism requires **unprivileged user-namespace creation**: `kernel.unprivileged_userns_clone=1` (or a kernel with it enabled) and `kernel.apparmor_restrict_unprivileged_userns=0` **or** an AppArmor profile for the binary. Measured on this host: `clone=1`, `apparmor_restrict=0`, label `unconfined`.

- Ubuntu 23.10+/24.04 ships `apparmor_restrict_unprivileged_userns=1` by default → **produce an AppArmor profile for the binary**, or document the requirement.
- Some container seccomp profiles block `CLONE_NEWUSER` → document.
- **Decide and report:** fail loudly with a diagnostic naming the requirement, or keep a setuid fallback? My recommendation is fail loudly and drop the setuid path entirely — the point is to remove that binary. But that's a product call, so bring it back rather than assume.

Also handle the case where the helper is invoked when already uid 0 (e.g. nested): writing `uid_map` with `lower_first == 0` needs `CAP_SETFCAP`. Detect "already root, don't remap" explicitly.

## 8. Acceptance criteria

- **Headline:** the tmpfs-dependent test files (`test/inkfish/sandbox`, `test/inkfish/uploads`, `test/inkfish_web/channels/clone_channel_test.exs`, `test/inkfish_web/controllers/api_v1/sub_controller_test.exs`) pass **unmodified** inside the nest bwrap sandbox — no `unshare` wrapper, no `CAP_SYS_ADMIN`, no nest changes. *(Caveat to check: Playwright launches Chromium with `--no-sandbox` by default, which should be fine as uid 0-in-namespace — verify, don't assume.)*
- The helper also works on the **host** (the primary production environment), unchanged.
- No setuid bit anywhere; `install.sh` no longer chmods 04555.
- Failure paths are bounded, loud, and tested.

## 9. Non-goals / do not propose

- **`:erl_tar`** for a code-enforced cap — ruled out by the user: it can't handle all the archives hit in practice, before we even get to bugs in it.
- Replacing the tmpfs with a plain directory, a PATH shim, or a test-only branch.
- Touching nest. Nothing in nest needs to change for any of this.
- Reimplementing the sanitizer in shell as a shortcut (§4).
- Changing test assertions without explicit approval.

## 10. Open questions to bring back

1. Sanitizer placement (§4) — with the measured VM-start cost.
2. Rust binary vs shell wrapper over `unshare(1)` — note `unshare(1)` is util-linux and may be absent; a Rust binary calling `unshare(2)` has no such dependency.
3. One wrapper invocation per call site, or a small long-lived helper.
4. Whether `safe_extract`'s `cp -r` out stays `cp -r` (it should) and whether anything else needs metadata preserved.
5. Whether the git script's `df` budget logic should take an explicit byte budget instead of reading `df` of the mount — it currently only works *because* the mount is capped.
6. Anything else that reads the tmpfs path outside the wrapper (the audit found none — `safe_extract` copies out to `target` — but confirm).

---

Sequencing suggestion for whoever runs it: land items 6–8 (failure handling) **first** — they're independent, small, and needed under every design; they're also what makes the rest verifiable. Then the API change and the call-site refactors.

Want me to turn this into work orders and run it with programmer minions here, or are you handing it to your own Inkfish team?
