#!/bin/bash

NODEJS_VER="22.17.0"
ERLANG_VER="27.3.4.1"
ELIXIR_VER="1.18.4-otp-27"

if [ ! -d ~/.asdf ]; then
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
fi

. "$HOME/.asdf/asdf.sh"

asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs $NODEJS_VER
asdf global nodejs $NODEJS_VER

# Desktop, Ubuntu 24.04
#sudo apt-get -y install build-essential autoconf m4 libncurses5-dev \
#    libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev libgl1-mesa-dev \
#    libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop \
#    libxml2-utils libncurses5-dev openjdk-11-jdk

#sudo apt-get -y install build-essential autoconf m4 libncurses5-dev \
#  libpng-dev libssh-dev unixodbc-dev xsltproc fop \
#  libxml2-utils libncurses-dev default-jdk

asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf install erlang $ERLANG_VER
asdf global erlang $ERLANG_VER

asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf install elixir $ELIXIR_VER
asdf global elixir $ELIXIR_VER

npm install --global corepack@latest
corepack enable pnpm

echo "Add the following to ~/.bashrc:"
echo
echo . "\$HOME/.asdf/asdf.sh"
echo . "\$HOME/.asdf/completions/asdf.bash"
