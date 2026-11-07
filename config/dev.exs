import Config

{:ok, hostname} = :inet.gethostname()

config :inkfish, :env, :dev
config :inkfish, :download_host, "http://#{hostname}:4000"

# Git-URL submissions. Two budgets, and they are not the same thing:
#
#   * `:git_clone_size` is the *checkout* budget: the temporary tmpfs that holds
#     the fetch. Nothing in it survives the clone, so it only has to be big
#     enough for the repository being cloned -- 100 MiB of temporary checkout to
#     find 5 MiB worth keeping is the intended trade.
#   * `:git_submit_size` is the *saved* budget: the bytes that persist for the
#     submission. It is enforced as a count of saved bytes, so tmpfs's 4 KiB
#     page-per-file cost does not eat it.
#   * `:git_max_files` is how many files the saved checkout may hold, because
#     that page cost is real: the persistent mount is sized as the saved budget
#     plus a page per allowed file.
#   * `:git_ignore` lists the directories that are never the student's own work
#     (installed dependencies, build output); they are matched against every
#     path component and never saved.
#   * `:git_blob_limit` is the largest blob worth downloading; it defaults to
#     the saved budget, since nothing larger can ever fit.
config :inkfish, :git_clone_size, "100m"
config :inkfish, :git_submit_size, "5m"
config :inkfish, :git_max_files, 2000

config :inkfish,
       :git_ignore,
       ~w(node_modules .pnpm bower_components .venv venv __pycache__ .tox .eggs
          .pytest_cache .mypy_cache .cache target dist build .gradle .next .nuxt
          coverage)

config :inkfish, :git_allowed_protocols, "https:http:git"

# Configure your database
config :inkfish, Inkfish.Repo,
  username: "inkfish",
  password: "oobeiGait3ie",
  database: "inkfish_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :inkfish, InkfishWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    asset_copy: {
      Phoenix.Copy,
      :watch,
      [:default]
    },
    esbuild: {
      Esbuild,
      :install_and_run,
      [:default, ~w(--sourcemap=inline --watch)]
    },
    sass: {
      DartSass,
      :install_and_run,
      [:default, ~w(--embed-source-map --source-map-urls=absolute --watch)]
    }
  ]

# Watch static and templates for browser reloading.
config :inkfish, InkfishWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/inkfish_web/(live|views|components)/.*(ex)$",
      ~r"lib/inkfish_web/(views|controllers)/.*(eex|heex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
