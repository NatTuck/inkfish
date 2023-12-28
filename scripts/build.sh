#!/bin/bash

if [[ -e ~/.asdf/asdf.sh ]]; then
    .  ~/.asdf/asdf.sh
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

