#!/bin/bash

DUMP=$(mix db.dump | tail -n 1)
UPSP=$(mix up.path | tail -n 1)
DATE=$(date +%Y%m%d-%s)

echo "dump =" $DUMP
echo "upsp =" $UPSP
echo "date =" $DATE
