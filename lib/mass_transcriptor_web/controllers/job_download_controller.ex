defmodule MassTranscriptorWeb.JobDownloadController do
  use MassTranscriptorWeb, :controller

  import MassTranscriptorWeb.UserAuth, only: [require_authenticated_user: 2]

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Jobs
  alias MassTranscriptor.Repo
  alias MassTranscriptor.Jobs.TranscriptionResult

  plug :require_authenticated_user when action in [:show]
  plug :assign_tenant_and_job when action in [:show]

  def show(conn, _params) do
    result = Repo.get_by(TranscriptionResult, job_id: conn.assigns.job.id)

    cond do
      is_nil(result) or is_nil(result.markdown_path) ->
        conn
        |> put_flash(:error, "Transcript file not found.")
        |> redirect(to: ~p"/t/#{conn.assigns.tenant_slug}/jobs/#{conn.assigns.job.id}")

      not File.exists?(result.markdown_path) ->
        conn
        |> put_flash(:error, "Transcript file not found.")
        |> redirect(to: ~p"/t/#{conn.assigns.tenant_slug}/jobs/#{conn.assigns.job.id}")

      true ->
        filename =
          conn.assigns.job.upload.original_filename
          |> Path.basename()
          |> Path.rootname()
          |> Kernel.<>(".md")

        conn
        |> put_resp_content_type("text/markdown")
        |> put_resp_header(
          "content-disposition",
          ~s(attachment; filename="#{filename}")
        )
        |> send_file(200, result.markdown_path)
    end
  end

  defp assign_tenant_and_job(conn, _opts) do
    tenant_slug = conn.params["tenant_slug"]
    job_id = String.to_integer(conn.params["id"])

    with %{} = user <- conn.assigns[:current_user],
         %{} = tenant <- Accounts.get_tenant_by_slug(tenant_slug),
         true <- Accounts.user_has_membership?(user.id, tenant.id),
         %{} = job <- Jobs.get_job_for_download(tenant.id, job_id) do
      conn
      |> assign(:tenant_slug, tenant_slug)
      |> assign(:job, job)
    else
      _ ->
        conn
        |> put_flash(:error, "Job not found.")
        |> redirect(to: ~p"/signin")
        |> halt()
    end
  end
end
