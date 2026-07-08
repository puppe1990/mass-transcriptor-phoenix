defmodule MassTranscriptor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    warn_missing_assemblyai_key()
    warn_missing_video_tools()

    children = [
      MassTranscriptorWeb.Telemetry,
      MassTranscriptor.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:mass_transcriptor, :ecto_repos), skip: skip_migrations?()},
      {Oban, Application.fetch_env!(:mass_transcriptor, Oban)},
      {DNSCluster, query: Application.get_env(:mass_transcriptor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MassTranscriptor.PubSub},
      # Start a worker by calling: MassTranscriptor.Worker.start_link(arg)
      # {MassTranscriptor.Worker, arg},
      # Start to serve requests, typically the last entry
      MassTranscriptorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MassTranscriptor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MassTranscriptorWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp warn_missing_assemblyai_key do
    if Application.get_env(:mass_transcriptor, :dev_routes) do
      case Application.get_env(:mass_transcriptor, :assemblyai_api_key) do
        key when key in [nil, ""] ->
          require Logger

          Logger.warning("""
          ASSEMBLYAI_API_KEY is not configured. Transcription jobs will fail.
          Add it to .env or export it before starting the server.
          """)

        _ ->
          :ok
      end
    end
  end

  defp warn_missing_video_tools do
    unless MassTranscriptor.Media.VideoConverter.available?() do
      require Logger

      Logger.warning("""
      ffmpeg/ffprobe are not available. Video uploads will fail until they are installed.
      """)
    end
  end

  defp skip_migrations? do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
