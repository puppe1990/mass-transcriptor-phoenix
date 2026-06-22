defmodule MassTranscriptorWeb.BatchDownloadController do
  use MassTranscriptorWeb, :controller

  import MassTranscriptorWeb.UserAuth, only: [require_authenticated_user: 2]

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Jobs

  plug :require_authenticated_user when action in [:show]
  plug :assign_tenant_and_batch when action in [:show]

  def show(conn, _params) do
    case Jobs.build_batch_transcripts_zip(conn.assigns.batch.jobs) do
      {:ok, binary} ->
        filename = "upload-group-#{conn.assigns.batch.id}.zip"

        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header(
          "content-disposition",
          ~s(attachment; filename="#{filename}")
        )
        |> send_resp(200, binary)

      {:error, :empty} ->
        conn
        |> put_flash(:error, "No transcripts available to download yet.")
        |> redirect(to: ~p"/t/#{conn.assigns.tenant_slug}/batches/#{conn.assigns.batch.id}")
    end
  end

  defp assign_tenant_and_batch(conn, _opts) do
    tenant_slug = conn.params["tenant_slug"]
    batch_id = String.to_integer(conn.params["id"])

    with %{} = user <- conn.assigns[:current_user],
         %{} = tenant <- Accounts.get_tenant_by_slug(tenant_slug),
         true <- Accounts.user_has_membership?(user.id, tenant.id),
         %{} = batch <- Jobs.get_batch_for_tenant(tenant.id, batch_id) do
      conn
      |> assign(:tenant_slug, tenant_slug)
      |> assign(:batch, batch)
    else
      _ ->
        conn
        |> put_flash(:error, "Batch not found.")
        |> redirect(to: ~p"/signin")
        |> halt()
    end
  end
end
