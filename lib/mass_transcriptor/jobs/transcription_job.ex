defmodule MassTranscriptor.Jobs.TranscriptionJob do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transcription_jobs" do
    field :provider_key, :string
    field :status, :string, default: "queued"
    field :error_message, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :tenant, MassTranscriptor.Accounts.Tenant
    belongs_to :upload, MassTranscriptor.Jobs.Upload
    belongs_to :batch, MassTranscriptor.Jobs.JobBatch

    has_one :result, MassTranscriptor.Jobs.TranscriptionResult, foreign_key: :job_id

    timestamps(type: :utc_datetime)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :tenant_id,
      :upload_id,
      :batch_id,
      :provider_key,
      :status,
      :error_message,
      :started_at,
      :completed_at
    ])
    |> validate_required([:tenant_id, :upload_id, :provider_key, :status])
  end
end
