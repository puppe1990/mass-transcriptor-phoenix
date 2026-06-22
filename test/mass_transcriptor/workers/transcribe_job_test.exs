defmodule MassTranscriptor.Workers.TranscribeJobTest do
  use MassTranscriptor.DataCase, async: false

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Jobs
  alias MassTranscriptor.Jobs.{TranscriptionJob, TranscriptionResult, Upload}
  alias MassTranscriptor.Repo
  alias MassTranscriptor.Storage
  alias MassTranscriptor.Workers.TranscribeJob

  setup do
    {:ok, %{tenant: tenant}} =
      Accounts.register_user(%{
        workspace_name: "Acme",
        workspace_slug: "acme",
        name: "Owner",
        email: "owner@example.com",
        password: "secret123"
      })

    Application.put_env(:mass_transcriptor, :transcription_provider, TestProvider)
    TestProvider.set_mode(:ok)
    on_exit(fn -> Application.delete_env(:mass_transcriptor, :transcription_provider) end)

    %{tenant: tenant}
  end

  test "marks job completed and stores markdown", %{tenant: tenant} do
    job = insert_job!(tenant, "sample.wav")

    assert :ok = Jobs.process_transcription_job(job.id)

    job = Repo.get!(TranscriptionJob, job.id)
    result = Repo.get_by!(TranscriptionResult, job_id: job.id)

    assert job.status == "completed"
    upload = Repo.get!(Upload, job.upload_id)
    assert result.transcript_text == "Transcript for #{upload.audio_path}"
    assert String.ends_with?(result.markdown_path, "transcript/transcript.md")
    assert File.exists?(result.markdown_path)
    assert Jason.decode!(result.provider_metadata_json) == %{"language" => "en"}
  end

  test "marks job failed when provider errors", %{tenant: tenant} do
    TestProvider.set_mode(:error)
    job = insert_job!(tenant, "sample.wav")

    assert {:error, _reason} = Jobs.process_transcription_job(job.id)

    job = Repo.get!(TranscriptionJob, job.id)
    assert job.status == "failed"
    assert job.error_message == "provider misconfigured"
    refute Repo.get_by(TranscriptionResult, job_id: job.id)
  end

  test "does not reprocess completed jobs", %{tenant: tenant} do
    job = insert_job!(tenant, "sample.wav")
    assert :ok = Jobs.process_transcription_job(job.id)

    TestProvider.set_mode(:error)

    assert :ok = Jobs.process_transcription_job(job.id)
    assert Repo.get!(TranscriptionJob, job.id).status == "completed"
  end

  test "perform delegates to Jobs.process_transcription_job/1", %{tenant: tenant} do
    job = insert_job!(tenant, "sample.wav")

    assert :ok = TranscribeJob.perform(%Oban.Job{args: %{"job_id" => job.id}})
    assert Repo.get!(TranscriptionJob, job.id).status == "completed"
  end

  defp insert_job!(tenant, filename) do
    audio_path = Storage.write_audio(tenant.slug, 99, filename, "fake-audio")

    {:ok, upload} =
      %Upload{}
      |> Ecto.Changeset.change(%{
        tenant_id: tenant.id,
        original_filename: filename,
        mime_type: "audio/wav",
        size_bytes: 10,
        audio_path: audio_path
      })
      |> Repo.insert()

    {:ok, job} =
      %TranscriptionJob{}
      |> Ecto.Changeset.change(%{
        tenant_id: tenant.id,
        upload_id: upload.id,
        provider_key: "assemblyai",
        status: "queued"
      })
      |> Repo.insert()

    job
  end
end

defmodule TestProvider do
  @behaviour MassTranscriptor.Transcription.Provider

  def set_mode(:error), do: :persistent_term.put({__MODULE__, :mode}, :error)
  def set_mode(_), do: :persistent_term.put({__MODULE__, :mode}, :ok)

  @impl true
  def transcribe(file_path, _opts) do
    case :persistent_term.get({__MODULE__, :mode}, :ok) do
      :error ->
        {:error, "provider misconfigured"}

      :ok ->
        {:ok, %{text: "Transcript for #{file_path}", metadata: %{"language" => "en"}}}
    end
  end
end
