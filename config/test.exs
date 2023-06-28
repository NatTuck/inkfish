import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :argon2_elixir, t_cost: 1, m_cost: 8

config :inkfish, :env, :test

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :inkfish, InkfishWeb.Endpoint,
  http: [port: 4002],
  server: true

# Configure your database
config :inkfish, Inkfish.Repo,
  username: "inkfish",
  password: "oobeiGait3ie",
  database: "inkfish_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :phoenix_integration,
  endpoint: InkfishWeb.Endpoint

config :hound,
  driver: "selenium",
  browser: "firefox",
  port: 4444

# Print only warnings and errors during test
config :logger, level: :warn
