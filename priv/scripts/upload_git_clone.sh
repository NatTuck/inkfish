#!/bin/bash
set -e

echo "Git clone config"
echo " - clone size: $CLONE_SIZE"
echo " - submit size: $SUBMIT_SIZE"
echo " - repo: $REPO"

echo "Creating temp dirs..."
CLONE_TMP=$(tmptmpfs start -s $CLONE_SIZE)
echo "  CLONE_TMP=$CLONE_TMP"
PERSIST_TMP=$(tmptmpfs start -s $SUBMIT_SIZE)
echo "  PERSIST_TMP=$PERSIST_TMP"

cd "$CLONE_TMP"
NAME=$(basename "$REPO" .git)
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
  type=$(echo "$spec" | awk '{ print $2 }')
  object=$(echo "$spec" | awk '{ print $3 }')

  # Submodules and other non-blob entries are not materialized.
  if [ "$type" != "blob" ]; then
    continue
  fi

  size=$(git cat-file -s "$object")
  size_kb=$(( (size + 1023) / 1024 ))

  mkdir -p "$OUT/$(dirname "$path")"

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
