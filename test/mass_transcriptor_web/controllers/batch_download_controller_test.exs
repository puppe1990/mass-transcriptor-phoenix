defmodule MassTranscriptorWeb.BatchDownloadControllerTest do
  use MassTranscriptorWeb.ConnCase, async: false

  import MassTranscriptorWeb.LiveCase, only: [log_in_user: 3]

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Jobs
  alias MassTranscriptor.Jobs.{TranscriptionJob, TranscriptionResult}
  alias MassTranscriptor.Repo
  alias MassTranscriptor.Storage

  setup %{conn: conn} do
    {:ok, %{user: user, tenant: tenant}} =
      Accounts.register_user(%{
        workspace_name: "Acme",
        workspace_slug: "acme",
        name: "Owner",
        email: "owner@example.com",
        password: "secret123"
      })

    {:ok, conn: log_in_user(conn, user, tenant), tenant: tenant}
  end

  test "downloads zip with all batch transcripts", %{conn: conn, tenant: tenant} do
    [first, second] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "first.ogg", mime_type: "audio/ogg", size: 4, content: "a"},
        %{filename: "second.ogg", mime_type: "audio/ogg", size: 4, content: "b"}
      ])

    complete_job!(tenant, first, "hello one")
    complete_job!(tenant, second, "hello two")

    conn =
      get(conn, ~p"/t/#{tenant.slug}/batches/#{first.batch_id}/download")

    zip_binary = response(conn, 200)

    assert get_resp_header(conn, "content-type") == ["application/zip; charset=utf-8"]

    assert get_resp_header(conn, "content-disposition") ==
             [~s(attachment; filename="upload-group-#{first.batch_id}.zip")]

    assert <<0x50, 0x4B, _rest::binary>> = zip_binary
    assert zip_binary =~ "first.md"
    assert zip_binary =~ "second.md"
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
