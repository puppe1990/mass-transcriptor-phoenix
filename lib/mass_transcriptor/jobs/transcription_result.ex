defmodule MassTranscriptor.Jobs.TranscriptionResult do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transcription_results" do
    field :markdown_path, :string
    field :transcript_text, :string
    field :provider_metadata_json, :string

    belongs_to :job, MassTranscriptor.Jobs.TranscriptionJob
    belongs_to :tenant, MassTranscriptor.Accounts.Tenant

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(result, attrs) do
    result
    |> cast(attrs, [
      :job_id,
      :tenant_id,
      :markdown_path,
      :transcript_text,
      :provider_metadata_json
    ])
    |> validate_required([:job_id, :tenant_id, :markdown_path, :transcript_text])
  end
end
