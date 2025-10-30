

# Setup for Amazon Linux 2023

## Inkfish User

```bash
sudo useradd -c 'Inkfish App' inkfish
```

## Docker

```bash
sudo yum install docker
sudo usermod -aG docker inkfish
```

## Core Deps

```bash
sudo yum install -y perl-core perl-doc perl-IPC-System-Simple perl-JSON git \
    ncurses-devel libxslt inotify-tools systemd-container nginx nginx-all-modules
yum groupinstall -y 'Development Tools'
```

## Postgres

```bash
sudo yum install postgresql15 postgresql15-server postgresql15-contrib libpq-devel
sudo postgresql-setup --initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo systemctl status postgresql
```

Once postgres is setup we can create the appropriate DB user.

We need to set up localhost password auth.

In ```pg_hba.conf```, we need the following rules, order matters:

```
# "local" is for Unix domain socket connections only
local   all             postgres                                peer
local   all             all                                     md5

# IPv4 local connections:
host    all             postgres        127.0.0.1/32            ident
host    all             all             127.0.0.1/32            md5

# IPv6 local connections:
host    all             postgres        ::1/128                 ident
host    all             all             ::1/128                 md5
```


## Install Elixir / Erlang

Check https://asdf-vm.com/guide/getting-started.html

```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs 20.11.1
asdf global nodejs 20.11.1
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf install erlang 26.2.2
asdf global erlang 26.2.2
asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf install elixir 1.16.1-otp-26
asdf global elixir 1.16.1-otp-26
```

## Firewall

```bash
yum install firewalld
sudo firewall-cmd --permanent --zone=public --add-port=4000/tcp
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --permanent --zone=public --add-port=443/tcp
sudo firewall-cmd --permanent --zone=public --add-port=22/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all --zone=public
```

# Rust for tmptmpfs

First, install https://rustup.rs/

Then install tmptmpfs.


# Setting up user service

Use "sudo machinectl shell --uid inkfish" to get a shell
for the Inkfish user with a correct session.

Service file goes in ~/.config/systemd/user

```bash
sudo loginctl enable-linger inkfish
```

As inkfish user:

```bash
systemctl --user enable inkfish
systemctl --user enable inkfish
```

## Nginx reverse proxy

Config file goes in /etc/nginx/conf.d and needs to have
a .conf extension.

```bash
systemctl enable nginx
systemctl start nginx
```

## Automatic Upgrades

In /etc/cron.daily/automatic-update

```bash
#!/bin/bash
/usr/bin/dnf upgrade --security --assumeyes --releasever=latest
```

Not sure this works.

## Other Notes

TODO:

 - Confirm service comes up on reboot.


