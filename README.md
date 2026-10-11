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

Install mise: <https://mise.jdx.dev/getting-started.html>

The toolchain is pinned in `.tool-versions`, which mise reads natively --
erlang, elixir, nodejs and pnpm. Run `mise install` in the repo to install
exactly those versions; there is no need to write a version number down
anywhere else.

Remember to install build deps for erlang, as listed for the erlang plugin
mise uses.

Keep `~/.local/share/mise/shims` ahead of any
`~/.local/share/mise/installs/*/bin` entries on `PATH`. The shims are what
resolve a tool through `.tool-versions`, while `mise activate` puts the install
directories first -- so a second toolchain installed beside the pinned one
would otherwise win. `scripts/start.sh` and the other scripts here fix this up
for themselves; see `scripts/install-mise.sh`.

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
