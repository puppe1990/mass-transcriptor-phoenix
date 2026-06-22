defmodule MassTranscriptor.Jobs.JobBatch do
  use Ecto.Schema

  schema "job_batches" do
    belongs_to :tenant, MassTranscriptor.Accounts.Tenant
    has_many :jobs, MassTranscriptor.Jobs.TranscriptionJob, foreign_key: :batch_id

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
