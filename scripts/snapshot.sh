#!/bin/bash

DUMP=$(mix db.dump | tail -n 1)
UPSP=$(mix up.path | tail -n 1)
DATE=$(date +%Y%m%d-%s)

echo "dump =" $DUMP
echo "upsp =" $UPSP
echo "date =" $DATE

DEST="/tmp/inksnaps/$DATE"
mkdir -p "$DEST"
cp -r "$UPSP" "$DEST/uploads"
bash -c "$DUMP" > "$DEST/dump.sql"
(cd "/tmp/inksnaps" && tar czf "$DATE.tar.gz" "$DATE")

ls -l "/tmp/inksnaps/$DATE.tar.gz"
