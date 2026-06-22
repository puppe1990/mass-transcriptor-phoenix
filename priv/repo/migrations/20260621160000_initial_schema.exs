defmodule MassTranscriptor.Repo.Migrations.InitialSchema do
  use Ecto.Migration

  def change do
    create table(:tenants) do
      add :slug, :string, null: false
      add :name, :string, null: false
      add :default_provider, :string, null: false, default: "assemblyai"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenants, [:slug])

    create table(:users) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:tenant_memberships) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "owner"

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:tenant_memberships, [:tenant_id])
    create index(:tenant_memberships, [:user_id])

    create table(:tenant_provider_settings) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :provider_key, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :config_json, :text

      timestamps(type: :utc_datetime)
    end

    create index(:tenant_provider_settings, [:tenant_id])

    create table(:uploads) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :original_filename, :string, null: false
      add :mime_type, :string, null: false
      add :size_bytes, :integer, null: false
      add :audio_path, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:uploads, [:tenant_id])

    create table(:job_batches) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:job_batches, [:tenant_id])

    create table(:transcription_jobs) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :upload_id, references(:uploads, on_delete: :delete_all), null: false
      add :batch_id, references(:job_batches, on_delete: :nilify_all)
      add :provider_key, :string, null: false
      add :status, :string, null: false, default: "queued"
      add :error_message, :string
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:transcription_jobs, [:upload_id])
    create index(:transcription_jobs, [:tenant_id])
    create index(:transcription_jobs, [:status])
    create index(:transcription_jobs, [:batch_id])

    create table(:transcription_results) do
      add :job_id, references(:transcription_jobs, on_delete: :delete_all), null: false
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :markdown_path, :string, null: false
      add :transcript_text, :text, null: false
      add :provider_metadata_json, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:transcription_results, [:job_id])
    create index(:transcription_results, [:tenant_id])
  end
end
