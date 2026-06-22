defmodule MassTranscriptor.Repo do
  use Ecto.Repo,
    otp_app: :mass_transcriptor,
    adapter: Ecto.Adapters.LibSql
end
