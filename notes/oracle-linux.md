
# Setup for Oracle Linux 9

## Docker

```bash
sudo yum install yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin \
	docker-compose-plugin
sudo docker run hello-world
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker
```

Then relog and try ```docker run hello-world```


## Core Deps

```bash
sudo yum-config-manager --add-repo https://yum.oracle.com/repo/OracleLinux/OL9/appstream/x86_64
sudo yum-config-manager --add-repo https://yum.oracle.com/repo/OracleLinux/OL9/addons/x86_64
sudo yum-config-manager --add-repo https://yum.oracle.com/repo/OracleLinux/OL9/developer/EPEL/x86_64
sudo yum update
sudo yum install -y perl-core perl-doc perl-IPC-System-Simple curl git \
	ncurses-devel libxslt inotify-tools systemd-container nginx \
	nginx-all-modules
sudo yum groupinstall -y 'Development Tools'
```

### Postgres

```
sudo yum install postgresql posgresql-server postgresql-contrib libpq-devel
sudo postgresql-setup --initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo systemctl status postgresql
```

Once postgres is setup we can create the appropriate DB user.


## Create App User

```bash
sudo useradd -c 'Inkfish App' inkfish
```

## Erlang, Elixir

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


## Open the appropriate ports

```bash
sudo firewall-cmd --permanent --zone=public --add-port=4000/tcp
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

```
sudo loginctl enable-linger inkfish
```

As inkfish user:

```bash
systemctl --user enable inkfish
systemctl --user enable inkfish
```

# Nginx reverse proxy

Config file goes in /etc/nginx/conf.d and needs to have
a .conf extension.

Need to allow network connections for nginx and enable it.

```
setsebool -P httpd_can_network_relay on
setsebool -P httpd_can_network_connect on
systemctl enable nginx
systemctl start nginx
```

# Config reminders

 - In production, the hostname in config/prod.exs needs to
   match the actual http request for websockets to work.

TODO:

 - Confirm service comes up on reboot.





