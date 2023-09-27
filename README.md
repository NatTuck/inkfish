
# Inkfish

System package dependencies:

```
sudo apt install docker.io imagemagick libipc-system-simple-perl
```

System user must be added to docker group.

## Setting up dev environment

Install asdf: https://github.com/asdf-vm/asdf

Use asdf to install latest erlang, elixir, node.

Remember to install build deps for erlang as listed in the asdf plugin.

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

## Future dep upgrades

Upgrade to Phx 1.6: https://gist.github.com/chrismccord/2ab350f154235ad4a4d0f4de6decba7b

 - Transition from .html.eex to .html.heex templates
 - Move from webpack to esbuild

## Phoenix README

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `npm install` inside the `assets` directory
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

 * Official website: https://www.phoenixframework.org/
 * Guides: https://hexdocs.pm/phoenix/overview.html
 * Docs: https://hexdocs.pm/phoenix
 * Forum: https://elixirforum.com/c/phoenix-forum
 * Source: https://github.com/phoenixframework/phoenix

## TODO

 * Initial time for date/time.
