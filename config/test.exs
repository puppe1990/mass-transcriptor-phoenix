import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mass_transcriptor, MassTranscriptor.Repo,
  database: Path.expand("../test.db", __DIR__) <> to_string(System.get_env("MIX_TEST_PARTITION")),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox,
  migrator: Oban.Migrations.SQLite

config :mass_transcriptor,
  storage_root: Path.expand("../tmp/storage", __DIR__),
  assemblyai_api_key: "test-key"

config :mass_transcriptor, Oban,
  testing: :disabled,
  engine: Oban.Engines.Lite,
  notifier: Oban.Notifiers.Isolated,
  queues: false,
  plugins: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mass_transcriptor, MassTranscriptorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "CKMlYZtyL2jH5Z143LfAhIxepOSbMskWbRBfdAysT7HByp8FYuYtOJcjMu/V/a/E",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
