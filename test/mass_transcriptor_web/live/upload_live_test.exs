defmodule MassTranscriptorWeb.UploadLiveTest do
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

  test "shows flash and success panel after starting transcription", %{conn: conn, tenant: tenant} do
    {:ok, view, _html} = live(conn, ~p"/t/#{tenant.slug}/uploads")

    file = %{name: "test.wav", content: "fake-audio", type: "audio/wav"}
    upload = file_input(view, "#upload-form", :audio, [file])
    render_upload(upload, "test.wav")

    html = view |> element("#upload-form") |> render_submit()

    [job] = Jobs.list_job_summaries_for_tenant(tenant.id)

    assert html =~ "upload-success"
    assert has_element?(view, "#upload-success")
    assert has_element?(view, "a[href=\"/t/#{tenant.slug}/jobs/#{job.id}\"]")
    assert html =~ "Job queued"
    assert has_element?(view, "#flash-info.flash-toast--info")
    refute has_element?(view, ".upload-file-card")
  end

  test "renders submitting indicator markup for phx-submit-loading", %{conn: conn, tenant: tenant} do
    {:ok, _view, html} = live(conn, ~p"/t/#{tenant.slug}/uploads")

    assert html =~ ~s(id="upload-submitting")
    assert html =~ "Uploading and queuing transcription"
  end

  test "accepts whatsapp ogg voice notes", %{conn: conn, tenant: tenant} do
    {:ok, view, _html} = live(conn, ~p"/t/#{tenant.slug}/uploads")

    file = %{
      name: "WhatsApp Ptt 2026-06-22 at 11.43.37.ogg",
      content: "fake-audio",
      type: "audio/ogg"
    }

    upload = file_input(view, "#upload-form", :audio, [file])
    render_upload(upload, "WhatsApp Ptt 2026-06-22 at 11.43.37.ogg")

    html = view |> element("#upload-form") |> render_submit()

    [job] = Jobs.list_job_summaries_for_tenant(tenant.id)

    assert html =~ "upload-success"
    assert job.original_filename == "WhatsApp Ptt 2026-06-22 at 11.43.37.ogg"
  end

  test "shows visible error when file type is not supported", %{conn: conn, tenant: tenant} do
    {:ok, view, _html} = live(conn, ~p"/t/#{tenant.slug}/uploads")

    file = %{name: "notes.txt", content: "plain-text", type: "text/plain"}
    upload = file_input(view, "#upload-form", :audio, [file])
    assert {:error, _errors} = render_upload(upload, "notes.txt")
    html = render(view)

    assert html =~ "Cannot upload this file"
    assert html =~ "notes.txt is not supported"
    assert has_element?(view, "#upload-error")
    assert has_element?(view, ".upload-dropzone--error")
  end

  test "shows hint when no files are selected", %{conn: conn, tenant: tenant} do
    {:ok, _view, html} = live(conn, ~p"/t/#{tenant.slug}/uploads")

    assert html =~ "Select at least one audio file"
    assert html =~ ~s(id="upload-empty-hint")
  end

  test "submit button shows uploading label while processing", %{conn: conn, tenant: tenant} do
    {:ok, view, _html} = live(conn, ~p"/t/#{tenant.slug}/uploads")

    file = %{name: "test.wav", content: "fake-audio", type: "audio/wav"}
    upload = file_input(view, "#upload-form", :audio, [file])
    render_upload(upload, "test.wav")

    assert has_element?(view, "#upload-submit[phx-disable-with]")
  end
end
