#!/bin/bash

# Toolchain: mise, with the shims authoritative. `.tool-versions` is the pin,
# and mise's shims are the only thing on PATH that resolves a tool *through* it:
# `mise activate` also exports `~/.local/share/mise/installs/<tool>/<version>/bin`
# and puts those ahead of `~/.local/share/mise/shims`, so with a second
# toolchain installed beside the pinned one (this repo has both elixir
# 1.18.4-otp-27 and 1.19.5-otp-28) an activated PATH resolves `elixir`, `erl`
# and `mix` to the unpinned version, and the release is built and run against
# the wrong Erlang/Elixir. Drop every `mise/installs/*/bin` entry and put the
# shims first, so the shims decide.
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
    . ~/.cargo/env
fi

export MIX_ENV=prod
export PORT=4080
export LANG=en_US.UTF-8
export DATABASE_URL=$(cat ~/.config/inkfish/db_url)
export SECRET_KEY_BASE=$(cat ~/.config/inkfish/key_base)
export MAILJET_KEY=$(cat ~/.config/inkfish/mailjet_key)

# The archive sanitizer runs as its own OS process inside the mount namespace,
# which inherits neither this shell's PATH nor `mise activate`'s environment, so
# hand it the absolute path of the `elixir` the shims just resolved rather than
# leaving it to re-resolve. `command -v` reports nothing and fails when the
# lookup finds nothing, so an unresolved `elixir` leaves this empty and
# `Inkfish.Sandbox.Archive.elixir_bin/0` falls through to its own lookup.
export INKFISH_ELIXIR_BIN="$(command -v elixir || true)"

#echo "Stopping old copy of app, if any..."

#_build/prod/rel/inkfish/bin/inkfish stop || true

echo "Starting app..."

printenv >/tmp/inkfish-env.debug

# Foreground for testing and systemd
_build/prod/rel/inkfish/bin/inkfish start | tee /home/inkfish/logs/prod.log
