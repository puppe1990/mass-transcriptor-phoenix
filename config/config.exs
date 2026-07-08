# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mime, :types, %{
  "audio/ogg" => ["ogg", "oga"]
}

config :mime, :extensions, %{
  "m4a" => "audio/mp4",
  "opus" => "audio/opus",
  "flac" => "audio/flac",
  "aac" => "audio/aac",
  "wma" => "audio/x-ms-wma",
  "mpga" => "audio/mpeg",
  "webm" => "audio/webm"
}

config :mass_transcriptor,
  ecto_repos: [MassTranscriptor.Repo],
  generators: [timestamp_type: :utc_datetime],
  storage_root: Path.expand("../storage", __DIR__),
  assemblyai_api_key: System.get_env("ASSEMBLYAI_API_KEY")

config :mass_transcriptor, Oban,
  repo: MassTranscriptor.Repo,
  engine: Oban.Engines.Lite,
  notifier: Oban.Notifiers.Isolated,
  queues: [transcription: 2],
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(10)}
  ]

config :mass_transcriptor, :job_stuck_after_minutes, 5

# Configure the endpoint
config :mass_transcriptor, MassTranscriptorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MassTranscriptorWeb.ErrorHTML, json: MassTranscriptorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MassTranscriptor.PubSub,
  live_view: [signing_salt: "3IuFzlCj"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  mass_transcriptor: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
