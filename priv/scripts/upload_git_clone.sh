#!/bin/bash
set -e

echo "Git clone config"
echo " - clone size: $CLONE_SIZE"
echo " - submit size: $SUBMIT_SIZE"
echo " - repo: $REPO"

# Only these protocols may be used by the fetch below. The caller
# (Inkfish.Uploads.Git) overrides this via the environment. We deliberately
# do not allow file://, ssh://, ext::, or bare local paths.
export GIT_ALLOW_PROTOCOL="${GIT_ALLOW_PROTOCOL:-https:http:git}"

echo "Creating temp dirs..."
CLONE_TMP=$(tmptmpfs start -s $CLONE_SIZE)
echo "  CLONE_TMP=$CLONE_TMP"
PERSIST_TMP=$(tmptmpfs start -s $SUBMIT_SIZE)
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
mkdir -p "$NAME"
cd "$NAME"

echo "Cloning git repo..."
git init -q
git remote add origin "$REPO"
git fetch --depth 1 origin -q
HEAD=$(git rev-parse FETCH_HEAD)
echo "  NAME=$NAME"
echo "  HEAD=$HEAD"

# The git repo (with fetched objects) lives in the roomy CLONE_TMP. The
# materialized working tree is written into PERSIST_TMP, which is the real
# budget for what stays persistent for the submission.
OUT="$PERSIST_TMP/$NAME"
mkdir -p "$OUT"

# Safety margin (KB) left free on the persistent tmpfs for directory entries
# and the trimmed git metadata, so a blob that *just* fits doesn't overflow.
MARGIN_KB=512

echo "Checking out files (budget-aware)..."
replaced=0

while IFS= read -r -d '' line; do
  # line format: <mode> SP <type> SP <object> TAB <path>
  spec=${line%%$'\t'*}
  path=${line#*$'\t'}
  mode=$(echo "$spec" | awk '{ print $1 }')
  type=$(echo "$spec" | awk '{ print $2 }')
  object=$(echo "$spec" | awk '{ print $3 }')

  # Submodules and other non-blob entries are not materialized.
  if [ "$type" != "blob" ]; then
    continue
  fi

  # Reject any path that could escape $OUT. Valid git trees never contain
  # empty, "." or ".." components, so this only fires on crafted repos.
  if [ -z "$path" ]; then
    echo "Invalid path in repo: ''" >&2
    exit 1
  fi
  IFS='/' read -r -a parts <<< "$path"
  for part in "${parts[@]}"; do
    case "$part" in
      ''|.|..)
        echo "Invalid path in repo: '$path'" >&2
        exit 1
        ;;
    esac
  done

  mkdir -p "$OUT/$(dirname "$path")"

  # Symlink entries (mode 120000) are stored as blobs whose content is the
  # link target. Preserve safe in-tree relative links; neutralize anything
  # absolute or escaping by writing the target string as a regular file.
  if [ "$mode" = "120000" ]; then
    target=$(git cat-file blob "$object")
    linkdir=$(dirname "$OUT/$path")
    safe=0
    if [ "${target#/}" = "$target" ]; then
      rel=$(realpath -m --relative-to="$OUT" "$linkdir/$target" 2>/dev/null || echo "")
      case "$rel" in
        ''|..|../*|/*) safe=0 ;;
        *) safe=1 ;;
      esac
    fi

    if [ "$safe" = "1" ]; then
      ln -s "$target" "$OUT/$path"
    else
      printf '%s' "$target" > "$OUT/$path"
      echo "  neutralized symlink: $path -> $target"
    fi
    continue
  fi

  size=$(git cat-file -s "$object")
  size_kb=$(( (size + 1023) / 1024 ))

  avail_kb=$(df -k "$OUT" | awk 'NR==2 { print $4 }')

  if [ "$size_kb" -le $((avail_kb - MARGIN_KB)) ]; then
    git cat-file blob "$object" > "$OUT/$path"
  else
    hash=$(git cat-file blob "$object" | sha256sum | cut -d' ' -f1)
    echo "$hash  $path" > "$OUT/$path.csum"
    echo "  replaced: $path -> $path.csum"
    replaced=$((replaced + 1))
  fi
done < <(git ls-tree -r -z "$HEAD")

echo "  replaced files: $replaced"

echo "Preserving git metadata (trimmed) for the persistent tree..."
mkdir -p "$OUT/.git"
for f in config HEAD shallow FETCH_HEAD; do
  if [ -f ".git/$f" ]; then
    cp ".git/$f" "$OUT/.git/$f"
  fi
done

echo "Creating tarball..."
TARB="$NAME.tar.gz"
echo "  TARB=$TARB"
tar -czf "$CLONE_TMP/$TARB" -C "$PERSIST_TMP" "$NAME"

echo ""
echo "Git checkout succeeded."

echo ""
echo "$COOKIE"
echo "dir: $OUT"
echo "tar: $CLONE_TMP/$TARB"
