defmodule MassTranscriptorWeb.BatchLiveTest do
  use MassTranscriptorWeb.LiveCase, async: false

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

  test "shows tabs for each audio in the group", %{conn: conn, tenant: tenant} do
    [first, second] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "first.ogg", mime_type: "audio/ogg", size: 4, content: "a"},
        %{filename: "second.ogg", mime_type: "audio/ogg", size: 4, content: "b"}
      ])

    complete_job!(tenant, first, "hello one")
    complete_job!(tenant, second, "hello two")

    {:ok, view, html} = live(conn, ~p"/t/#{tenant.slug}/batches/#{first.batch_id}")

    assert html =~ "Upload group"
    assert html =~ "2 audios"
    assert has_element?(view, "#batch-download-all")

    assert has_element?(
             view,
             "a#batch-download-all[href=\"/t/#{tenant.slug}/batches/#{first.batch_id}/download\"]"
           )

    assert has_element?(view, "#batch-tab-#{first.id}")
    assert has_element?(view, "#batch-tab-#{second.id}")
    assert html =~ "hello one"
    refute html =~ "hello two"

    view |> element("#batch-tab-#{second.id}") |> render_click()

    html = render(view)
    assert html =~ "hello two"
    refute html =~ "hello one"
  end

  test "shows retry button for failed jobs", %{conn: conn, tenant: tenant} do
    [job, _other] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "failed.wav", mime_type: "audio/wav", size: 4, content: "data"},
        %{filename: "ok.wav", mime_type: "audio/wav", size: 4, content: "data"}
      ])

    {:error, _} =
      Jobs.mark_job_failed(
        Jobs.fetch_job!(job.id),
        "AssemblyAI requires ASSEMBLYAI_API_KEY to be configured on the server"
      )

    {:ok, view, html} = live(conn, ~p"/t/#{tenant.slug}/batches/#{job.batch_id}")

    assert html =~ "ASSEMBLYAI_API_KEY"
    assert has_element?(view, "#retry-job-#{job.id}")

    view |> element("#retry-job-#{job.id}") |> render_click()

    assert render(view) =~ "status-queued"
  end

  test "redirects when batch is not found", %{conn: conn, tenant: tenant} do
    assert {:error, {:redirect, %{to: path}}} =
             live(conn, ~p"/t/#{tenant.slug}/batches/99999")

    assert path == ~p"/t/#{tenant.slug}/jobs"
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
