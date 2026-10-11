#!/bin/bash

BINSRC="./target/debug/tmptmpfs"
BINDST="/usr/local/bin/tmptmpfs"

if [[ $USER != "root" ]]; then
    echo "Run with sudo"
    exit 1
fi

if [[ ! -e "$BINSRC" ]]; then
    echo "Run 'cargo build' first"
    exit 1
fi

# Plain install: no setuid bit. The helper gets the privileges it needs from
# an unprivileged user namespace, so it must never be installed setuid root.
cp "$BINSRC" "$BINDST"
chmod 0755 "$BINDST"
