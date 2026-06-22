defmodule MassTranscriptor.Jobs.UploadTest do
  use MassTranscriptor.DataCase, async: false

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Jobs
  alias MassTranscriptor.Jobs.{JobBatch, TranscriptionJob}
  alias MassTranscriptor.Repo

  setup do
    {:ok, %{tenant: tenant}} =
      Accounts.register_user(%{
        workspace_name: "Acme",
        workspace_slug: "acme",
        name: "Owner",
        email: "owner@example.com",
        password: "secret123"
      })

    %{tenant: tenant}
  end

  test "single upload creates one queued assemblyai job", %{tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "sample.wav", mime_type: "audio/wav", size: 10, content: "fake-audio"}
      ])

    assert job.status == "queued"
    assert job.provider_key == "assemblyai"
    refute job.batch_id
  end

  test "multiple uploads share a batch", %{tenant: tenant} do
    jobs =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "a.wav", mime_type: "audio/wav", size: 10, content: "a"},
        %{filename: "b.wav", mime_type: "audio/wav", size: 10, content: "b"}
      ])

    assert length(jobs) == 2
    batch_ids = Enum.map(jobs, & &1.batch_id) |> Enum.uniq()
    assert length(batch_ids) == 1
    assert hd(batch_ids)
    assert Repo.aggregate(JobBatch, :count) == 1
  end

  test "persists audio on disk", %{tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "sample.wav", mime_type: "audio/wav", size: 10, content: "fake-audio"}
      ])

    upload = Repo.get!(MassTranscriptor.Jobs.Upload, job.upload_id)
    assert File.exists?(upload.audio_path)
  end

  test "enqueues oban job", %{tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "sample.wav", mime_type: "audio/wav", size: 10, content: "fake-audio"}
      ])

    assert Repo.get_by(Oban.Job, worker: "MassTranscriptor.Workers.TranscribeJob")

    assert %Oban.Job{args: %{"job_id" => id}} =
             Repo.get_by(Oban.Job, worker: "MassTranscriptor.Workers.TranscribeJob")

    assert id == job.id
  end
end
