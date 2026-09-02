#!/bin/bash
set -e

echo "Git clone config"
echo " - max size: $SIZE"
echo " - repo: $REPO"

echo "Creating temp dir..."
TMP1=$(tmptmpfs start -s $SIZE)
echo "  TMP1=$TMP1"

cd "$TMP1"
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

# Safety margin (KB) left free on the tmpfs for the git pack/objects and
# directory entries, so a blob that *just* fits doesn't push the mount over.
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

  mkdir -p "$(dirname "$path")"

  avail_kb=$(df -k . | awk 'NR==2 { print $4 }')

  if [ "$size_kb" -le $((avail_kb - MARGIN_KB)) ]; then
    git cat-file blob "$object" > "$path"
  else
    hash=$(git cat-file blob "$object" | sha256sum | cut -d' ' -f1)
    echo "$hash  $path" > "$path.csum"
    echo "  replaced: $path -> $path.csum"
    replaced=$((replaced + 1))
  fi
done < <(git ls-tree -r -z "$HEAD")

echo "  replaced files: $replaced"

echo "Creating tarball..."
TMP2=$(tmptmpfs start -s $SIZE)
TARB="$NAME.tar.gz"
echo "  TMP2=$TMP2"
echo "  TARB=$TARB"
cd "$TMP1" && tar czvf "$TMP2/$TARB" "$NAME"

echo ""
echo "Git checkout succeeded."

echo ""
echo "$COOKIE"
echo "dir: $TMP1/$NAME"
echo "tar: $TMP2/$TARB"
