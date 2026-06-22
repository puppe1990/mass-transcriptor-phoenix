defmodule MassTranscriptorWeb.UserAuth do
  @moduledoc false

  use MassTranscriptorWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias MassTranscriptor.Accounts

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont,
     Phoenix.Component.assign_new(socket, :current_user, fn ->
       if user_id = session["user_id"], do: Accounts.get_user!(user_id)
     end)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket =
      Phoenix.Component.assign_new(socket, :current_user, fn ->
        if user_id = session["user_id"], do: Accounts.get_user!(user_id)
      end)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/signin")}
    end
  end

  def on_mount(:ensure_tenant_member, %{"tenant_slug" => tenant_slug}, session, socket) do
    socket =
      socket
      |> Phoenix.Component.assign_new(:current_user, fn ->
        if user_id = session["user_id"], do: Accounts.get_user!(user_id)
      end)
      |> Phoenix.Component.assign(:tenant_slug, tenant_slug)

    with %{} = user <- socket.assigns[:current_user],
         %{} = tenant <- Accounts.get_tenant_by_slug(tenant_slug),
         true <- Accounts.user_has_membership?(user.id, tenant.id) do
      {:cont, Phoenix.Component.assign(socket, :current_tenant, tenant)}
    else
      _ ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/signin")}
    end
  end

  def log_in_user(conn, user, tenant \\ nil) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> maybe_put_tenant_slug(tenant)
    |> put_flash(:info, "Welcome back!")
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> delete_session(:user_id)
    |> delete_session(:tenant_slug)
    |> redirect(to: ~p"/signin")
  end

  def fetch_current_user(conn, _opts) do
    if user_id = get_session(conn, :user_id) do
      assign(conn, :current_user, Accounts.get_user!(user_id))
    else
      assign(conn, :current_user, nil)
    end
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must sign in to access this page.")
      |> redirect(to: ~p"/signin")
      |> halt()
    end
  end

  defp maybe_put_tenant_slug(conn, nil), do: conn

  defp maybe_put_tenant_slug(conn, tenant) do
    put_session(conn, :tenant_slug, tenant.slug)
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
