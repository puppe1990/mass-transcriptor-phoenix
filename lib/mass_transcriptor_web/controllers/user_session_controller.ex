defmodule MassTranscriptorWeb.UserSessionController do
  use MassTranscriptorWeb, :controller

  alias MassTranscriptor.Accounts
  alias MassTranscriptorWeb.UserAuth

  @session_salt "user session"

  def create(conn, %{"token" => token, "return_to" => return_to}) do
    case Phoenix.Token.verify(MassTranscriptorWeb.Endpoint, @session_salt, token, max_age: 60) do
      {:ok, user_id} ->
        user = Accounts.get_user!(user_id)
        tenant = Accounts.list_memberships_for_user(user.id) |> List.first() |> Map.get(:tenant)

        conn
        |> UserAuth.log_in_user(user, tenant)
        |> redirect(to: return_to)

      {:error, _reason} ->
        conn
        |> put_flash(:error, gettext("Authentication failed"))
        |> redirect(to: ~p"/signin")
    end
  end

  def delete(conn, _params) do
    UserAuth.log_out_user(conn)
  end
end
