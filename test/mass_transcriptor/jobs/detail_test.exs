defmodule MassTranscriptor.Jobs.DetailTest do
  use MassTranscriptor.DataCase, async: false

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Jobs
  alias MassTranscriptor.Jobs.{TranscriptionJob, TranscriptionResult}
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

  test "get_batch_for_tenant/2 returns batch with ordered job details", %{tenant: tenant} do
    [first, second] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "first.ogg", mime_type: "audio/ogg", size: 4, content: "a"},
        %{filename: "second.ogg", mime_type: "audio/ogg", size: 4, content: "b"}
      ])

    batch_id = first.batch_id

    complete_job!(tenant, first, "hello one")
    complete_job!(tenant, second, "hello two")

    assert %{
             id: ^batch_id,
             jobs: [job_one, job_two]
           } = Jobs.get_batch_for_tenant(tenant.id, batch_id)

    assert job_one.original_filename == "first.ogg"
    assert job_one.transcript_text == "hello one"
    assert job_two.original_filename == "second.ogg"
    assert job_two.transcript_text == "hello two"
  end

  test "get_batch_for_tenant/2 returns nil for another tenant", %{tenant: tenant} do
    [job | _] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "a.wav", mime_type: "audio/wav", size: 4, content: "a"},
        %{filename: "b.wav", mime_type: "audio/wav", size: 4, content: "b"}
      ])

    {:ok, %{tenant: other}} =
      Accounts.register_user(%{
        workspace_name: "Other",
        workspace_slug: "other",
        name: "Owner",
        email: "other@example.com",
        password: "secret123"
      })

    refute Jobs.get_batch_for_tenant(other.id, job.batch_id)
  end

  test "get_job_detail_for_tenant/2 returns job detail", %{tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "sample.wav", mime_type: "audio/wav", size: 4, content: "data"}
      ])

    complete_job!(tenant, job, "hello transcript")

    detail = Jobs.get_job_detail_for_tenant(tenant.id, job.id)

    assert detail.original_filename == "sample.wav"
    assert detail.transcript_text == "hello transcript"
    assert detail.markdown_path
  end

  test "retry_job/1 requeues failed jobs", %{tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "failed.wav", mime_type: "audio/wav", size: 4, content: "data"}
      ])

    {:error, _} = Jobs.mark_job_failed(Jobs.fetch_job!(job.id), "boom")

    assert {:ok, %TranscriptionJob{status: "queued", error_message: nil}} =
             Jobs.retry_job(Jobs.fetch_job!(job.id))
  end

  test "build_batch_transcripts_zip/1 returns zip with one markdown per completed job", %{
    tenant: tenant
  } do
    [first, second] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "first.ogg", mime_type: "audio/ogg", size: 4, content: "a"},
        %{filename: "second.ogg", mime_type: "audio/ogg", size: 4, content: "b"}
      ])

    complete_job!(tenant, first, "hello one")
    complete_job!(tenant, second, "hello two")

    batch = Jobs.get_batch_for_tenant(tenant.id, first.batch_id)

    assert {:ok, zip_binary} = Jobs.build_batch_transcripts_zip(batch.jobs)
    assert is_binary(zip_binary)
    assert byte_size(zip_binary) > 0

    assert <<0x50, 0x4B, _rest::binary>> = zip_binary
    assert zip_binary =~ "first.md"
    assert zip_binary =~ "second.md"
  end

  test "retry_job/1 requeues stuck queued jobs", %{tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "stuck.wav", mime_type: "audio/wav", size: 4, content: "data"}
      ])

    stuck_job =
      Jobs.fetch_job!(job.id)
      |> TranscriptionJob.changeset(%{})
      |> Ecto.Changeset.put_change(
        :inserted_at,
        DateTime.utc_now() |> DateTime.add(-10, :minute) |> DateTime.truncate(:second)
      )
      |> Repo.update!()

    assert Jobs.stuck?(stuck_job)

    assert {:ok, %TranscriptionJob{status: "queued"}} = Jobs.retry_job(stuck_job)
  end

  test "retry_job/1 rejects fresh queued jobs when not stuck", %{tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "queued.wav", mime_type: "audio/wav", size: 4, content: "data"}
      ])

    job = Jobs.fetch_job!(job.id)

    refute Jobs.stuck?(job)
    assert {:error, :not_retryable} = Jobs.retry_job(job)
  end

  defp complete_job!(tenant, job, transcript_text) do
    markdown_path =
      Storage.write_markdown(
        tenant.slug,
        job.upload_id,
        "# Transcript\n\n#{transcript_text}"
      )

    %TranscriptionResult{}
    |> TranscriptionResult.changeset(%{
      job_id: job.id,
      tenant_id: tenant.id,
      markdown_path: markdown_path,
      transcript_text: transcript_text,
      provider_metadata_json: "{}"
    })
    |> Repo.insert!()

    job
    |> TranscriptionJob.changeset(%{status: "completed", completed_at: DateTime.utc_now()})
    |> Repo.update!()
  end
end
