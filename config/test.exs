import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :argon2_elixir, t_cost: 1, m_cost: 8

config :inkfish, :env, :test

config :inkfish, :time_zone, "Africa/Nairobi"
config :local_time, :time_zone, "Africa/Nairobi"

config :inkfish, :git_clone_size, "100m"
config :inkfish, :git_submit_size, "5m"
config :inkfish, :git_allowed_protocols, "https:http:git:file"

# A real tmpfs mount takes milliseconds; keep the bound short so a broken
# `tmptmpfs` fails fast instead of hanging the suite.
config :inkfish, :tempfs_timeout_ms, 2_000

# `Archive.safe_extract/3` bounds the whole extraction pipeline (mount, tar,
# Erlang VM boot, one `readlink -f` fork per relative symlink, copy-out) with
# its own, more generous default. Keep the test bound tight so a broken helper
# still fails fast rather than waiting out the production default.
config :inkfish, :extract_timeout_ms, 5_000

# The unprivileged `tmptmpfs` is built here. It must be named explicitly: the
# old setuid-root binary is still installed at /usr/local/bin/tmptmpfs and
# would win the PATH lookup.
config :inkfish,
  tmptmpfs_bin:
    Path.expand("../support/tmptmpfs/target/debug/tmptmpfs", __DIR__)

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

config :phoenix_test,
  endpoint: InkfishWeb.Endpoint,
  otp_app: :inkfish,
  base_url: "http://localhost:4002"

config :ex_unit,
  tmp_dir: "/tmp/ex_unit"

# Print only warnings and errors during test
config :logger, level: :warning
