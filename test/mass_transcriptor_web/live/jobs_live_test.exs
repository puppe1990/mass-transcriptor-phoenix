defmodule MassTranscriptorWeb.JobsLiveTest do
  use MassTranscriptorWeb.LiveCase, async: false

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Jobs

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

  test "shows empty state when tenant has no jobs", %{conn: conn, tenant: tenant} do
    {:ok, _view, html} = live(conn, ~p"/t/#{tenant.slug}/jobs")

    assert html =~ "No jobs yet"
    assert html =~ ~s(href="/t/#{tenant.slug}/uploads")
  end

  test "lists jobs with status badges", %{conn: conn, tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "sample.wav", mime_type: "audio/wav", size: 4, content: "data"}
      ])

    {:ok, view, html} = live(conn, ~p"/t/#{tenant.slug}/jobs")

    assert html =~ "sample.wav"
    assert html =~ "assemblyai"
    assert has_element?(view, "#jobs-table")
    assert has_element?(view, "span.status-#{job.status}")
    assert has_element?(view, "a[href=\"/t/#{tenant.slug}/jobs/#{job.id}\"]")
  end

  test "groups batch uploads into one row", %{conn: conn, tenant: tenant} do
    Jobs.create_uploads_and_jobs(tenant, [
      %{filename: "a.wav", mime_type: "audio/wav", size: 4, content: "a"},
      %{filename: "b.wav", mime_type: "audio/wav", size: 4, content: "b"}
    ])

    {:ok, view, html} = live(conn, ~p"/t/#{tenant.slug}/jobs")

    assert html =~ "2 audios"
    assert html =~ "a.wav"
    assert html =~ "b.wav"
    refute html =~ ~s(href="/t/#{tenant.slug}/jobs/1")
    assert has_element?(view, "a[href*=\"/batches/\"]")
  end

  test "shows error message for failed jobs", %{conn: conn, tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "failed.wav", mime_type: "audio/wav", size: 4, content: "data"}
      ])

    {:error, _} =
      Jobs.mark_job_failed(
        Jobs.fetch_job!(job.id),
        "AssemblyAI requires ASSEMBLYAI_API_KEY to be configured on the server"
      )

    {:ok, view, html} = live(conn, ~p"/t/#{tenant.slug}/jobs")

    assert html =~ "ASSEMBLYAI_API_KEY"
    assert has_element?(view, "#job-row-#{job.id} .jobs-table__error")
  end

  test "refreshes list on poll when jobs are active", %{conn: conn, tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "poll.wav", mime_type: "audio/wav", size: 4, content: "data"}
      ])

    {:ok, view, _html} = live(conn, ~p"/t/#{tenant.slug}/jobs")

    assert {:ok, _job} = Jobs.mark_job_processing(Jobs.fetch_job!(job.id))

    send(view.pid, :poll)

    assert render(view) =~ "status-processing"
  end
end
