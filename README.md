
  <h2>Grading Script Output</h2>

  <.form for={%{}} action={~p"/subs/#{@sub}/rerun_scripts"} method="post">
    <.button class="btn btn-secondary">Rerun Scripts</.button>
  </.form>

  <%= for {grade, token, log} <- @autogrades do %>
  <h3><%= grade.grade_column.name %></h3>
    <%= if log do %>
      <p><strong>Sandbox Exit Status</strong></p>
      <pre><%= log["status"] %></pre>
      <p><strong>Test Output</strong></p>
      <pre><%= log["result"] %></pre>
      <p><strong>Full Log</strong></p>
      <pre><%= render_autograde_log(log["log"]) %></pre>
    <% else %>
      <div id="itty-root"
          data-token={token}
          data-chan="autograde"
          data-uuid={grade.log_uuid}>
        <!-- React component in js/itty.jsx -->
        Loading...
      </div>
    <% end %>
  <% end %>
<% end %>

<%= if log do %>
    <p><strong>Sandbox Exit Status</strong></p>
    <pre><%= log["status"] %></pre>
    <p><strong>Test Output</strong></p>
    <pre><%= log["result"] %></pre>
    <p><strong>Full Log</strong></p>
    <pre><%= render_autograde_log(log["log"]) %></pre>
  <% else %>
    <div id="itty-root"
    data-token={token}
    data-chan="autograde"
    data-uuid={grade.log_uuid}>
    <!-- React component in js/itty.jsx -->
    Loading...
    </div>

    <p>
    Once the grading script has completed, you can reload this page to see
    your autograding score.
    </p>
    <% end %>

# Inkfish

## System Requirements

Minimum system requirements:

- A dedicated (virtual) server running Debian 12
- 2 GB of RAM
- 50 GB of disk space

Recommended system requirements:

- A dedicated (virtual) server running Debian 12
- 8 GB of RAM
- 200 GB of disk space
- 4 dedicated CPU cores

The recommended requirements would enable:

- Faster deployment of updates when using the server to do in-place
   application builds.
- Shorter student wait times for test results.
- The ability to test student code under multi-core execution,
   including parellel speedup and concurrent correctness.

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

## Future dep upgrades

Upgrade to Phx 1.6: <https://gist.github.com/chrismccord/2ab350f154235ad4a4d0f4de6decba7b>

- Transition from .html.eex to .html.heex templates
- Move from webpack to esbuild

## Phoenix README

To start your Phoenix server:

- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.setup`
- Install Node.js dependencies with `npm install` inside the `assets` directory
- Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

- Official website: <https://www.phoenixframework.org/>
- Guides: <https://hexdocs.pm/phoenix/overview.html>
- Docs: <https://hexdocs.pm/phoenix>
- Forum: <https://elixirforum.com/c/phoenix-forum>
- Source: <https://github.com/phoenixframework/phoenix>

## TODO

- Initial time for date/time.
