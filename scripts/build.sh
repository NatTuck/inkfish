#!/bin/bash

# Toolchain: mise, with the shims authoritative. `.tool-versions` is the pin,
# and mise's shims are the only thing on PATH that resolves a tool *through* it:
# `mise activate` also exports `~/.local/share/mise/installs/<tool>/<version>/bin`
# and puts those ahead of `~/.local/share/mise/shims`, so with a second
# toolchain installed beside the pinned one (this repo has both elixir
# 1.18.4-otp-27 and 1.19.5-otp-28) an activated PATH resolves `elixir`, `erl`
# and `mix` to the unpinned version, and `_build` is rebuilt against the wrong
# Erlang/Elixir. Drop every `mise/installs/*/bin` entry and put the shims first,
# so the shims decide.
MISE_SHIMS="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
if [[ -d "$MISE_SHIMS" ]]; then
    mise_rest=""
    IFS=: read -r -a mise_parts <<<"$PATH"
    for mise_part in "${mise_parts[@]}"; do
        case "$mise_part" in
            "$MISE_SHIMS"|*/mise/installs/*/bin) continue ;;
        esac
        mise_rest="${mise_rest:+$mise_rest:}$mise_part"
    done
    export PATH="$MISE_SHIMS:$mise_rest"
    unset mise_rest mise_parts mise_part
fi

if [[ -e .cargo/env ]]; then
    .  ~/.cargo/env
fi

export MIX_ENV=prod
export PORT=4080
export DATABASE_URL=FAKE_DB
export SECRET_KEY_BASE=SECRET_KEY
export LANG="en_US.utf8"
export LC_ALL="en_US.UTF-8"

echo "Building..."

mkdir -p ~/.config
mkdir -p priv/static

mix deps.get
mix compile
#mix ecto.migrate

export NODEBIN=`pwd`/assets/node_modules/.bin
export PATH="$PATH:$NODEBIN"

(cd assets && npm install)
mix assets.deploy

echo "Generating release..."
mix release --overwrite

