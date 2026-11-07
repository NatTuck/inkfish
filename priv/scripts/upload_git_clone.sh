#!/bin/bash
set -e

# Byte semantics everywhere: the saved budget is counted in bytes, and both
# `${#var}` and `tr` count characters rather than bytes under a UTF-8 locale.
# Nothing here should depend on the locale of whoever deployed this.
export LC_ALL=C

# CLONE_TMP and PERSIST_TMP are two size-capped tmpfs mounts, and a mount
# namespace is private to the process that created it, so the caller has to
# create them. It does: `Inkfish.Uploads.Git.start_clone/1` runs this script
# through `Inkfish.Sandbox.TempFs.unshare_argv/3`, whose preamble mounts
# CLONE_TMP and PERSIST_TMP -- capped at `$CLONE_SIZE` and `$SUBMIT_SIZE` -- and
# exports their paths. The mounts live only inside that namespace, so they, and
# the directories holding them, are gone once this script exits.
#
# That is what makes the two assertions below real checks: they catch this
# script being run without that sandbox, and say so, rather than letting it fail
# with a confusing EROFS from the first write below.
: "${CLONE_TMP:?CLONE_TMP is not set: this script must run inside the tempfs sandbox that Inkfish.Sandbox.TempFs.unshare_argv/3 creates}"
: "${PERSIST_TMP:?PERSIST_TMP is not set: this script must run inside the tempfs sandbox that Inkfish.Sandbox.TempFs.unshare_argv/3 creates}"

# There are two budgets, and they mean different things:
#
#   * the *checkout* budget (CLONE_TMP, `$CLONE_SIZE`, `:git_clone_size`) is
#     temporary. It holds the fetch's packfile and nothing else, and it is
#     thrown away when this script exits. Temporarily spending 100 MiB here to
#     find the 5 MiB worth keeping is the point of the split.
#   * the *saved* budget (PERSIST_TMP, `$SUBMIT_SIZE`, `:git_submit_size`) is
#     what persists: the checkout that is copied out and becomes the upload.
#     It is enforced below as a count of *bytes of saved data*, not as free
#     space on the mount, because tmpfs charges a full 4 KiB page per file --
#     so free space and saved bytes are different numbers, and a repository
#     with many small files would otherwise exhaust the budget on page
#     granularity alone. The mount is sized with that overhead added
#     (`Inkfish.Uploads.Git` does the arithmetic) and remains the backstop.
echo "Git clone config"
echo " - checkout budget (temporary): $CLONE_SIZE"
echo " - saved budget (persisted): $SUBMIT_SIZE"
echo " - file limit: ${MAX_FILES:-2000}"
echo " - repo: $REPO"

# Only these protocols may be used by the fetch below. The caller
# (Inkfish.Uploads.Git) overrides this via the environment. We deliberately
# do not allow file://, ssh://, ext::, or bare local paths.
export GIT_ALLOW_PROTOCOL="${GIT_ALLOW_PROTOCOL:-https:http:git}"

# The names matched against every path component of the checkout. These are the
# directories that are always somebody's installed dependencies or build
# output, and never the student's own work. The caller passes the list from
# `:git_ignore`; the fallback is the same list the default config carries.
# Entries are plain names (no globs, no slashes).
GIT_IGNORE="${GIT_IGNORE:-node_modules .pnpm bower_components .venv venv __pycache__ .tox .eggs .pytest_cache .mypy_cache .cache target dist build .gradle .next .nuxt coverage}"
# `read -a` reads one line, so a value with a newline in it would silently lose
# everything after the first line; flatten it first.
read -ra IGNORE_PARTS <<< "${GIT_IGNORE//$'\n'/ }"

MAX_FILES="${MAX_FILES:-2000}"
case "$MAX_FILES" in
  ''|*[!0-9]*)
    echo "error: MAX_FILES='$MAX_FILES' is not a number." >&2
    exit 1
    ;;
esac

# A budget string (`5m`, `100k`, `512`) as a byte count. An empty answer means
# the value is not one we can reason about (a percentage, say), and the caller
# is told so rather than being given a number we made up.
to_bytes() {
  case "$1" in
    *[kK]) echo $(( ${1%?} * 1024 )) ;;
    *[mM]) echo $(( ${1%?} * 1024 * 1024 )) ;;
    *[gG]) echo $(( ${1%?} * 1024 * 1024 * 1024 )) ;;
    *[0-9]) echo "$1" ;;
    *) echo "" ;;
  esac
}

SAVE_BYTES=$(to_bytes "$SUBMIT_SIZE")
if [ -z "$SAVE_BYTES" ]; then
  echo "error: the saved budget SUBMIT_SIZE='$SUBMIT_SIZE' is not a byte count." >&2
  echo "It is compared against the bytes this script writes, so it has to be one (5m, 512k, ...)." >&2
  exit 1
fi

echo "Creating temp dirs..."
echo "  CLONE_TMP=$CLONE_TMP"
echo "  PERSIST_TMP=$PERSIST_TMP"

cd "$CLONE_TMP"
NAME=$(basename "$REPO" .git)
# Keep the checkout directory name to a safe slug. A crafted URL can
# otherwise yield an empty name, "." or "..", which would place $OUT
# outside the persistent tmpfs.
NAME=$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9._-' '_')
case "$NAME" in
  ''|.|..) NAME="repo" ;;
esac

# ---------------------------------------------------------------------------
# Which commit? The remote's default branch, and nothing else.
#
# `git remote add origin "$REPO"` installs the refspec
# `+refs/heads/*:refs/remotes/origin/*`, so a bare `git fetch --depth 1 origin`
# downloads the tip of *every* branch -- and `git rev-parse FETCH_HEAD` then
# takes the first line of a multi-branch FETCH_HEAD, which is whichever ref
# sorts first, not the default branch. A repository with an abandoned branch
# carrying a committed `node_modules` therefore fetched tens of megabytes and
# checked out the wrong branch. `ls-remote --symref` asks the remote what its
# default branch is, and the explicit refspec fetches exactly that one.
# ---------------------------------------------------------------------------
echo "Resolving the default branch..."
# A failure here is git's to report -- "does not appear to be a git repository"
# names the URL -- so the script lets it through with git's own exit status
# rather than replacing the message.
REMOTE_HEAD=$(git ls-remote --symref -- "$REPO" HEAD)

# `ref: refs/heads/main<TAB>HEAD` is the symref line; `<sha><TAB>HEAD` is the
# commit it points at. A remote whose HEAD is detached has no symref line, and
# an empty repository has neither.
BRANCH=$(printf '%s\n' "$REMOTE_HEAD" |
  awk -F'\t' '$1 ~ /^ref: / && $2 == "HEAD" { sub(/^ref: refs\/heads\//, "", $1); print $1 }')
HEAD_SHA=$(printf '%s\n' "$REMOTE_HEAD" |
  awk -F'\t' '$1 !~ /^ref: / && $2 == "HEAD" { print $1 }')

if [ -z "$BRANCH" ] && [ -z "$HEAD_SHA" ]; then
  echo "error: $REPO has no commits: its HEAD does not point at anything." >&2
  exit 1
fi

if [ -n "$BRANCH" ]; then
  # The branch name becomes a refspec argument and a shell word. It cannot
  # contain a space or start with `-` if it is a real ref, so refusing those
  # costs nothing and keeps the name from being read as an option. The
  # whitelist also keeps out `*`: a refspec is a *pattern*, so a remote that
  # advertised `ref: refs/heads/*` would otherwise re-fetch the tip of every
  # branch -- exactly the fetch this script exists to avoid.
  case "$BRANCH" in
    -*|*[!A-Za-z0-9._/+@-]*)
      echo "error: refusing to fetch a branch named '$BRANCH'." >&2
      exit 1
      ;;
  esac
  REFSPEC="refs/heads/$BRANCH"
  echo "  branch=$BRANCH"
else
  # A detached HEAD is rare on a forge, but a sha is still fetchable from most
  # servers; when it is not, git's own message says so.
  REFSPEC="$HEAD_SHA"
  echo "  branch=(detached) $HEAD_SHA"
fi

mkdir -p "$NAME"
cd "$NAME"

echo "Cloning git repo..."
git init -q
git remote add -- origin "$REPO"

# Never download a blob larger than the entire saved budget: it cannot be
# saved, so downloading it only spends the checkout budget and the student's
# time. The caller passes `$BLOB_LIMIT` (the saved budget by default) and an
# empty value turns the filter off; a server that does not support partial
# clone only warns, and the fetch degrades to a plain depth-1 fetch.
case "${BLOB_LIMIT:-}" in
  '')
    FETCH_FILTER=""
    ;;
  *[!0-9kKmMgG]*)
    echo "error: BLOB_LIMIT='$BLOB_LIMIT' is not a git size (100k, 5m, ...)." >&2
    exit 1
    ;;
  *)
    FETCH_FILTER="--filter=blob:limit=$BLOB_LIMIT"
    ;;
esac

if git fetch --depth 1 --no-tags -q $FETCH_FILTER origin -- "$REFSPEC"; then
  :
else
  # Git has already said what went wrong; this adds the one thing it cannot
  # know -- which budget ran out -- and keeps git's own exit status.
  status=$?
  echo "error: could not fetch ${BRANCH:-$HEAD_SHA} from $REPO." >&2
  echo "The temporary checkout budget is CLONE_SIZE=$CLONE_SIZE; a default branch larger" >&2
  echo "than that cannot be fetched. Raise :git_clone_size to allow larger repositories." >&2
  exit "$status"
fi
SHA=$(git rev-parse FETCH_HEAD)
echo "  NAME=$NAME"
echo "  HEAD=$SHA"

# Keep the origin URL -- `Inkfish.Uploads.Git.repo_info/1` reads it back out of
# the persisted `.git/config` -- and then drop the remote. A `--filter` fetch
# leaves blobs out of the packfile, and git fetches those on demand from the
# remote it was fetched from: any object lookup below would quietly re-download
# exactly what the filter was meant to skip. With the remote gone, a missing
# blob is simply missing.
cp .git/config "$CLONE_TMP/config.keep"
git remote remove origin

# The persistent checkout. The git repo (with its fetched packfile) lives in
# the roomy CLONE_TMP; only what survives the filter is written here.
OUT="$PERSIST_TMP/$NAME"
mkdir -p "$OUT"

# Matches the ignore list against every path component, so `a/node_modules/b`
# is excluded as surely as a top-level `node_modules`.
is_ignored() {
  local path="/$1/" name
  for name in "${IGNORE_PARTS[@]}"; do
    case "$path" in
      */"$name"/*) return 0 ;;
    esac
  done
  return 1
}

# Valid git trees never contain empty, "." or ".." components, so this only
# fires on crafted repos -- but it has to fire before anything is written.
# Matching the whole path against the three bad shapes is the same test as
# splitting on `/` and checking each component, without the splitting (which
# would glob a path containing `*`).
check_path() {
  local path=$1
  if [ -z "$path" ]; then
    echo "Invalid path in repo: ''" >&2
    exit 1
  fi
  case "/$path/" in
    *//*|*/./*|*/../*)
      echo "Invalid path in repo: '$path'" >&2
      exit 1
      ;;
  esac
}

# One line per entry, NUL-terminated so a path containing a newline survives:
# `<mode> SP <type> SP <object> SP <size> TAB <path>`. `-l` reports the size,
# and for a blob the fetch filter left out it reports a non-numeric size
# (`BAD`), which is how a never-downloaded blob is recognised without asking
# git for it -- that question is what would trigger a lazy fetch.
echo "Listing $BRANCH..."
git ls-tree -r -l -z "$SHA" > "$CLONE_TMP/tree.lst"

# Is some directory component of `path` a symlink this tree already created?
# Pure parameter expansion: no forks, no globbing, no word splitting. Prints the
# offending component, which is what the error names.
under_symlink() {
  local rest=$1 acc="" part
  while [ "${rest#*/}" != "$rest" ]; do
    part=${rest%%/*}
    rest=${rest#*/}
    if [ -z "$acc" ]; then acc=$part; else acc="$acc/$part"; fi
    if [ -n "${SYMLINK[$acc]:-}" ]; then
      echo "$acc"
      return 0
    fi
  done
  return 1
}

# First pass: what would we write? Nothing is written yet, so a repository that
# cannot fit is refused with the numbers, instead of dying half way through with
# whatever `write` happened to fail on.
#
# The symlinks seen so far are remembered because a git tree can contain both a
# symlink `a` and an entry under it (`a/f`): a normal commit cannot, but a
# crafted tree can, and writing `a/f` after `ln -s a` writes *through* the link,
# outside the checkout. Git's order is depth-first, so the link always comes
# first and one pass sees it.
declare -A SYMLINK
entries=0
excluded=0
excluded_bytes=0
while IFS= read -r -d '' line; do
  spec=${line%%$'\t'*}
  path=${line#*$'\t'}
  # shellcheck disable=SC2086 # `spec` is four whitespace-separated fields
  set -- $spec
  mode=$1; type=$2; sha=$3; size=$4

  # Submodules and other non-blob entries are not materialized.
  if [ "$type" != "blob" ]; then
    continue
  fi
  check_path "$path"

  if bad=$(under_symlink "$path"); then
    echo "error: refusing to check out '$path': it is inside the symlink '$bad'." >&2
    echo "Git does not produce trees like that; writing the entry would write through" >&2
    echo "the link and out of the checkout." >&2
    exit 1
  fi

  if [ "$mode" = "120000" ]; then
    SYMLINK[$path]=1
  fi

  case "$size" in
    ''|*[!0-9]*) size=0 ;;
  esac

  if is_ignored "$path"; then
    excluded=$((excluded + 1))
    excluded_bytes=$((excluded_bytes + size))
    continue
  fi

  entries=$((entries + 1))
done < "$CLONE_TMP/tree.lst"

# The saved budget is a tmpfs, so every entry costs at least one 4 KiB page no
# matter how small its contents are -- a placeholder `.csum` costs one too. A
# repository with more entries than that can hold cannot be saved at all, and
# the only honest answer is to say so and name the knob.
if [ "$entries" -gt "$MAX_FILES" ]; then
  echo "error: this repository's default branch ($BRANCH) has $entries files after the" >&2
  echo "standard ignore list, and the limit is $MAX_FILES." >&2
  echo "The saved checkout is a tmpfs, which charges at least one 4 KiB page per file," >&2
  echo "so a tree with more entries than this cannot be saved even if it is nearly empty." >&2
  echo "Raise :git_max_files (and :git_submit_size, if the contents need it) to allow it." >&2
  exit 1
fi

avail_kb=$(df -k "$PERSIST_TMP" | awk 'NR==2 { print $4 }')
need_kb=$(( entries * 4 + 64 ))
if [ "$need_kb" -gt "$avail_kb" ]; then
  echo "error: this repository's default branch ($BRANCH) has $entries files, which needs" >&2
  echo "at least ${need_kb} KiB of the saved checkout, and only ${avail_kb} KiB are available." >&2
  echo "Raise :git_max_files (and :git_submit_size, if the contents need it) to allow it." >&2
  exit 1
fi

echo "Checking out files (saved budget-aware)..."
total=0
written=0
replaced=0
neutralized=0
notices=0

# Only the first few per-file notices are printed: a repository where most of
# the tree does not fit, or which is made of symlinks with kilobyte targets,
# would otherwise print a line per file and trip the itty view's output limit
# before the clone could report anything at all.
REPORT_MAX=50

notice() {
  notices=$((notices + 1))
  if [ "$notices" -le "$REPORT_MAX" ]; then
    echo "  $1"
  elif [ "$notices" -eq $((REPORT_MAX + 1)) ]; then
    echo "  ... only the first $REPORT_MAX per-file notices are listed"
  fi
}

write_csum() {
  mkdir -p -- "$OUT/$(dirname -- "$1")"
  if ! printf '%s  %s\n' "$2" "$1" > "$OUT/$1.csum"; then
    echo "error: the saved budget ($SUBMIT_SIZE) could not hold the checkout: writing" >&2
    echo "$1.csum ran out of space. Raise :git_submit_size to allow a larger checkout." >&2
    exit 1
  fi
}

report_replaced() {
  replaced=$((replaced + 1))
  notice "replaced: $1 -> $1.csum"
}

while IFS= read -r -d '' line; do
  spec=${line%%$'\t'*}
  path=${line#*$'\t'}
  # shellcheck disable=SC2086 # `spec` is four whitespace-separated fields
  set -- $spec
  mode=$1; type=$2; object=$3; size=$4

  # Submodules and other non-blob entries are not materialized.
  if [ "$type" != "blob" ]; then
    continue
  fi
  check_path "$path"

  if is_ignored "$path"; then
    continue
  fi

  # A non-numeric size means the fetch filter left this blob out, so it was
  # never downloaded. There is no content to write, but the object id is
  # known, which is what the placeholder records.
  case "$size" in
    ''|*[!0-9]*)
      write_csum "$path" "$object"
      report_replaced "$path"
      continue
      ;;
  esac

  mkdir -p -- "$OUT/$(dirname -- "$path")"

  # Symlink entries (mode 120000) are stored as blobs whose content is the
  # link target. Preserve safe in-tree relative links; neutralize anything
  # absolute or escaping by writing the target string as a regular file.
  if [ "$mode" = "120000" ]; then
    target=$(git cat-file blob "$object")

    # A link's saved bytes are its target's bytes: they are part of the budget
    # like any file's content, or a tree of links with megabyte targets would
    # be saved for free.
    if [ $((total + ${#target})) -gt "$SAVE_BYTES" ]; then
      write_csum "$path" "$object"
      report_replaced "$path"
      continue
    fi

    linkdir=$(dirname -- "$OUT/$path")
    safe=0
    if [ -n "$target" ] && [ "${target#/}" = "$target" ]; then
      rel=$(realpath -m --relative-to="$OUT" -- "$linkdir/$target" 2>/dev/null || echo "")
      case "$rel" in
        ''|..|../*|/*) safe=0 ;;
        *) safe=1 ;;
      esac
    fi

    if [ "$safe" = "1" ]; then
      ln -s -- "$target" "$OUT/$path"
    else
      printf '%s' "$target" > "$OUT/$path"
      neutralized=$((neutralized + 1))
      notice "neutralized symlink: $path -> ${target:0:60}"
    fi

    total=$((total + ${#target}))
    written=$((written + 1))
    continue
  fi

  # The saved budget is spent on the tree in path order: the first files that
  # fit are kept verbatim, and everything after it becomes a placeholder. That
  # keeps the outcome deterministic and never exceeds the budget.
  if [ $((total + size)) -le "$SAVE_BYTES" ]; then
    git cat-file blob "$object" > "$OUT/$path"
    # `git cat-file blob` writes bytes, not modes: the executable bit has to be
    # restored by hand or every script in the checkout comes back non-executable.
    if [ "$mode" = "100755" ]; then
      chmod +x -- "$OUT/$path"
    fi
    total=$((total + size))
    written=$((written + 1))
  else
    write_csum "$path" "$object"
    report_replaced "$path"
  fi
done < "$CLONE_TMP/tree.lst"

echo "  replaced files: $replaced"
echo "  neutralized symlinks: $neutralized"

# Symlink containment has to be decided on the *finished* tree. `realpath -m`
# treats a component that does not exist yet as a plain directory, so a link
# written early can be made to resolve outside $OUT by a link written after it:
#
#     m/x    -> z/b/b/b/../../../..    (looks inside: m/z/b does not exist yet)
#     m/z/b  -> .                      (now every `b` is a directory to climb)
#
# This walk applies the same rule `Inkfish.Sandbox.SanitizeLinks` applies to
# archives -- an absolute target goes, anything that resolves outside $OUT goes,
# anything that cannot be resolved goes -- and it is the authority the per-entry
# check above cannot be. `create_upload/3` runs the Elixir sanitizer over the
# staged tree as well, for the same reason the archive path does.
sanitize_links() {
  local link raw resolved removed=0
  while IFS= read -r -d '' link; do
    raw=$(readlink -- "$link" 2>/dev/null || echo "")
    case "$raw" in
      /*|'')
        rm -f -- "$link"
        removed=$((removed + 1))
        notice "removed unsafe symlink: ${link#"$OUT"/} -> $raw"
        continue
        ;;
    esac

    resolved=$(readlink -f -- "$link" 2>/dev/null || echo "")
    case "$resolved" in
      "$OUT"|"$OUT"/*) ;;
      *)
        rm -f -- "$link"
        removed=$((removed + 1))
        notice "removed unsafe symlink: ${link#"$OUT"/} -> $raw"
        ;;
    esac
  done < <(find "$OUT" -type l -print0)

  echo "  removed unsafe symlinks: $removed"
}

sanitize_links

echo "Preserving git metadata (trimmed) for the persistent tree..."
# `.git` has to be a real directory of ours. A crafted tree can contain an entry
# named `.git` (a normal commit cannot), and the writes below must not follow it
# anywhere -- the sanitizer above has already removed it if it escaped, but a
# link to a directory *inside* the checkout would still send the metadata to the
# wrong place.
if [ -e "$OUT/.git" ] || [ -L "$OUT/.git" ]; then
  rm -rf -- "$OUT/.git"
fi
mkdir -p -- "$OUT/.git"
# The saved config keeps the origin URL (`repo_info/1` reads it) but not the
# keys that would let anything in the unpacked tree go back to the network: the
# partial-clone ones (`--filter` writes them) and the fetch refspec.
grep -v -E '^[[:space:]]*(promisor|partialclonefilter|fetch)[[:space:]]*=' \
  "$CLONE_TMP/config.keep" > "$OUT/.git/config" || true
for f in HEAD shallow FETCH_HEAD; do
  if [ -f ".git/$f" ]; then
    cp -- ".git/$f" "$OUT/.git/$f"
  fi
done
# The fetched commit, not the unborn local branch `git init` left behind.
printf '%s\n' "$SHA" > "$OUT/.git/HEAD"

echo "Creating tarball..."
TARB="$NAME.tar.gz"
echo "  TARB=$TARB"
tar -czf "$CLONE_TMP/$TARB" -C "$PERSIST_TMP" "$NAME"

# The tmpfs mounts live only inside the mount namespace this script runs in,
# so every path under them is gone the moment we exit -- but the caller has to
# be able to read the checkout and the tarball afterwards. Copy both out to a
# directory on the real filesystem (which the namespace shares) and report
# those paths. `cp -r` copies symlinks as symlinks rather than following them,
# which is what keeps the checkout faithful.
#
# The staging directory is owned by the caller: when it passes STAGE_DIR we use
# that, so it always knows the path and can remove it even if this script dies
# before reporting anything. Only fall back to making our own `mktemp -d` when
# no STAGE_DIR was given.
STAGE="${STAGE_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/inkfish-clone-XXXXXX")}"
cp -r "$OUT" "$STAGE/$NAME"
cp "$CLONE_TMP/$TARB" "$STAGE/$TARB"
OUT="$STAGE/$NAME"
TARB="$STAGE/$TARB"

echo ""
echo "Git checkout succeeded."
echo "  branch: $BRANCH"
echo "  commit: $SHA"
echo "  saved: $written files, $((total / 1024)) KiB of $SUBMIT_SIZE"
echo "  excluded by the ignore list: $excluded files, $((excluded_bytes / 1024)) KiB"
echo "  neutralized symlinks: $neutralized"

echo ""
echo "$COOKIE"
echo "stage: $STAGE"
echo "dir: $OUT"
echo "tar: $TARB"
