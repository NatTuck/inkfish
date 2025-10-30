# Inkfish

## System Requirements

Minimum system requirements:

- A dedicated (virtual) server running Debian Stable
- 4 GB of RAM
- 50 GB of disk space

Recommended system requirements:

- A dedicated (virtual) server running Debian Stable
- 8+ GB of RAM
- 200 GB of disk space
- 4 dedicated CPU cores

## Deps

Partial system package dependencies:

```
sudo apt install docker.io docker-buildx graphicsmagick libipc-system-simple-perl
```

System user must be added to docker group.

Erlang, Elixir, and NodeJS need to be installed somehow. System
packages from Debian repos are likely to provide the best automatic
update behavior.

## Setting up dev environment

Install asdf: <https://github.com/asdf-vm/asdf>

Use asdf to install latest erlang, elixir, node.

Remember to install build deps for erlang as listed in the asdf plugin.

Install tmptmptfs:

- Install rustup
- In support/tmptmtpfs do cargo build
- Then run sudo ./install.sh

Install dev deps:

```
sudo apt install inotify-tools
```

Install postgresql:

```
sudo apt install postgresql-all postgresql-client libpq-dev
```

Create dev user:

```
user$ sudo su - postgres
postgres$ createuser -d -P inkfish
password: oobeiGait3ie
```
