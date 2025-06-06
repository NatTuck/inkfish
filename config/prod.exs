import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix phx.digest` task,
# which you should run after static files are built and
# before starting your production server.
config :inkfish, InkfishWeb.Endpoint,
  url: [host: "inkfish.homework.quest", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"

config :inkfish, Inkfish.Users.User,
  domain: "usnh.edu",
  domains: ["usnh.edu", "ferrus.net"]

config :inkfish, download_host: "https://inkfish.homework.quest"
config :inkfish, :env, :prod

config :inkfish, Inkfish.Mailer,
  adapter: Swoosh.Adapters.Sendmail,
  cmd_path: "/usr/sbin/sendmail",
  cmd_args: "",
  send_from: {"Inkfish", "no-reply@homework.quest"}

# Do not print debug messages in production
config :logger, level: :info

# Finally import the config/prod.secret.exs which loads secrets
# and configuration from environment variables.
import_config "prod.secret.exs"
