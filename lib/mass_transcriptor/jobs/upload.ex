defmodule MassTranscriptor.Jobs.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  schema "uploads" do
    field :original_filename, :string
    field :mime_type, :string
    field :size_bytes, :integer
    field :audio_path, :string

    belongs_to :tenant, MassTranscriptor.Accounts.Tenant

    has_one :job, MassTranscriptor.Jobs.TranscriptionJob

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def create_changeset(upload, attrs) do
    upload
    |> cast(attrs, [:tenant_id, :original_filename, :mime_type, :size_bytes])
    |> validate_required([:tenant_id, :original_filename, :mime_type, :size_bytes])
  end

  def audio_changeset(upload, attrs) do
    upload
    |> cast(attrs, [:audio_path])
    |> validate_required([:audio_path])
  end
end
