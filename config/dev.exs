import Config

{:ok, hostname} = :inet.gethostname()

config :inkfish, :env, :dev
config :inkfish, :download_host, "http://#{hostname}:4000"

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
