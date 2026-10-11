#!/bin/bash

# Install the toolchain this repo pins. `.tool-versions` is the single pin and
# mise reads it natively, so nothing here repeats a version number:
#
#     nodejs 24   erlang 28   elixir 1.19.5-otp-28   pnpm 11
#
# Erlang is built from source, so its build deps have to be installed first --
# see `scripts/add-erl-build-deps.sh`.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v mise >/dev/null 2>&1; then
    curl https://mise.run | sh
fi

# mise installs itself into ~/.local/bin. Put it on PATH for this script, and
# arrange for future shells to get it too.
export PATH="$HOME/.local/bin:$PATH"

if ! grep -q 'mise activate' "$HOME/.bashrc" 2>/dev/null; then
    echo 'eval "$(~/.local/bin/mise activate bash)"' >>"$HOME/.bashrc"
fi

# Install exactly what `.tool-versions` pins, then print what resolved.
mise install
mise current

echo
echo "mise is on PATH via ~/.bashrc. The shims in ~/.local/share/mise/shims are"
echo "what resolve each tool through .tool-versions; keep them ahead of any"
echo "~/.local/share/mise/installs/*/bin entries on PATH."
