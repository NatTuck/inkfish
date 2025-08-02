#!/bin/bash

if [[ -e ~/.asdf/asdf.sh ]]; then
    . ~/.asdf/asdf.sh
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

#echo "Stopping old copy of app, if any..."

#_build/prod/rel/inkfish/bin/inkfish stop || true

echo "Starting app..."

printenv >/tmp/inkfish-env.debug

# Foreground for testing and systemd
_build/prod/rel/inkfish/bin/inkfish start | tee /home/inkfish/logs/prod.log
