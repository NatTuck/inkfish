#!/bin/bash

export ERLANG=26.1.2
export ELIXIR=1.15.7-otp-26
export NODEJS=20.9.0

git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
. "$HOME/.asdf/asdf.sh"

asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf install erlang $ERLANG
asdf global erlang $ERLANG

asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf install elixir $ELIXIR
asdf global elixir $ELIXIR

asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs $NODEJS
asdf global nodejs $NODEJS

elixir --version
node --version

