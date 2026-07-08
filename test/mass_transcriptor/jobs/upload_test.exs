defmodule MassTranscriptor.Jobs.UploadTest do
  use MassTranscriptor.DataCase, async: false

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Jobs
  alias MassTranscriptor.Jobs.{JobBatch, Upload}
  alias MassTranscriptor.Repo
  alias MassTranscriptor.Storage

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

  test "video upload stores source file and enqueues conversion", %{tenant: tenant} do
    source = write_temp_file("fake-video")

    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{
          filename: "clip.mp4",
          mime_type: "video/mp4",
          size: 11,
          source_path: source
        }
      ])

    upload = Repo.get!(Upload, job.upload_id)
    source_path = Storage.build_source_path(tenant.slug, upload.id, "clip.mp4")

    assert upload.audio_path == "pending_conversion"
    assert File.exists?(source_path)
    refute Repo.get_by(Oban.Job, worker: "MassTranscriptor.Workers.TranscribeJob")

    assert %Oban.Job{args: %{"upload_id" => upload_id}} =
             Repo.get_by(Oban.Job, worker: "MassTranscriptor.Workers.ConvertVideoJob")

    assert upload_id == upload.id
  end

  test "mark_job_completed removes video media but keeps audio uploads", %{tenant: tenant} do
    source = write_temp_file("fake-video")

    [video_job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{
          filename: "clip.mp4",
          mime_type: "video/mp4",
          size: 11,
          source_path: source
        }
      ])

    [audio_job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "sample.wav", mime_type: "audio/wav", size: 10, content: "fake-audio"}
      ])

    video_job = Jobs.fetch_job!(video_job.id)
    audio_job = Jobs.fetch_job!(audio_job.id)

    assert {:ok, _} =
             Jobs.mark_job_completed(video_job, %{text: "video transcript", metadata: %{}})

    assert {:ok, _} =
             Jobs.mark_job_completed(audio_job, %{text: "audio transcript", metadata: %{}})

    video_upload = Repo.get!(Upload, video_job.upload_id)
    audio_upload = Repo.get!(Upload, audio_job.upload_id)

    refute File.exists?(Storage.build_source_dir(tenant.slug, video_upload.id))

    refute File.exists?(
             Path.join(Storage.build_upload_dir(tenant.slug, video_upload.id), "audio")
           )

    assert File.exists?(audio_upload.audio_path)
  end

  defp write_temp_file(content) do
    path = Path.join(System.tmp_dir!(), "tmp-#{System.unique_integer([:positive])}.mp4")
    File.write!(path, content)
    path
  end
end
