# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :inkfish, Inkfish.Users.UserNotifier,
  domains: ["example.com", "example.org"]

config :inkfish, Inkfish.Users.User,
  domain: "example.com"

config :inkfish,
  ecto_repos: [Inkfish.Repo],
  generators: [timestamp_type: :utc_datetime]

config :inkfish, Inkfish.Repo,
  migration_timestamps: [type: :utc_datetime]

# Configures the endpoint
config :inkfish, InkfishWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "V2mJIKEOJpyjppjtVUT2Zl4Rc24vEyI9FPA0DUQE/UW9ZmPLr/uRsgofj5E3yJnp",
  render_errors: [view: InkfishWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Inkfish.PubSub,
  live_view: [signing_salt: "37rUe00e"]

config :inkfish, Inkfish.Autobots,
  concurrency: 1

config :inkfish, Inkfish.Mailer,
   adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Force a default time zone.
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
config :inkfish, :time_zone, "America/New_York"

config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(js/app.js --bundle --target=es2018 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :dart_sass,
  version: "1.61.0",
  default: [
    args: ~w(--load-path=./node_modules css/app.scss ../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]

config :phoenix_copy,
  default: [
    source: Path.expand("../assets/static/", __DIR__),
    destination: Path.expand("../priv/static/", __DIR__),
    debounce: 100
  ],
  bs_icons: [
    source: Path.expand("../assets/node_modules/bootstrap-icons/icons/", __DIR__),
    destination: Path.expand("../priv/static/images/icons/", __DIR__),
    debounce: 100
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
