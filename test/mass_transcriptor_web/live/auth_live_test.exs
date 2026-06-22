defmodule MassTranscriptorWeb.AuthLiveTest do
  use MassTranscriptorWeb.LiveCase, async: false

  alias MassTranscriptor.Accounts

  test "renders sign up route", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/signup")

    assert html =~ "Create Workspace"
    assert html =~ "Turn raw audio into structured notes."
  end

  test "renders sign in route", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/signin")

    assert html =~ "Sign In"
    assert html =~ "Welcome back"
  end

  test "sign in page links to sign up", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/signin")
    assert html =~ ~s(href="/signup")
    assert html =~ "Create Workspace"
  end

  test "sign up page links to sign in", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/signup")
    assert html =~ ~s(href="/signin")
    assert html =~ "Sign In Instead"
  end

  test "password field has visibility toggle on sign in", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/signin")
    assert has_element?(view, "button", "Show password")
  end

  test "password visibility toggle switches input type", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/signin")

    assert has_element?(view, "#user_password[type=\"password\"]")

    view |> element("button", "Show password") |> render_click()

    assert has_element?(view, "#user_password[type=\"text\"]")
  end

  test "sign up creates workspace and grants access to uploads", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/signup")

    view
    |> form("#sign-up-form", %{
      user: %{
        workspace_name: "Acme",
        workspace_slug: "acme",
        name: "Owner",
        email: "owner@example.com",
        password: "secret123"
      }
    })
    |> render_submit()

    user = Accounts.get_user_by_email("owner@example.com")
    tenant = Accounts.get_tenant_by_slug("acme")
    assert user
    assert tenant

    conn = log_in_user(conn, user, tenant)
    {:ok, _view, html} = live(conn, ~p"/t/acme/uploads")

    assert html =~ "Upload Audio"
    assert html =~ "acme"
  end

  test "sign in with invalid credentials shows error", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/signin")

    view
    |> form("#sign-in-form", %{user: %{email: "missing@example.com", password: "wrong"}})
    |> render_submit()

    assert render(view) =~ "Authentication failed"
  end

  test "sign in redirects to tenant uploads", %{conn: conn} do
    {:ok, %{user: user, tenant: tenant}} =
      Accounts.register_user(%{
        workspace_name: "Acme",
        workspace_slug: "acme",
        name: "Owner",
        email: "owner@example.com",
        password: "secret123"
      })

    {:ok, view, _html} = live(conn, ~p"/signin")

    view
    |> form("#sign-in-form", %{user: %{email: user.email, password: "secret123"}})
    |> render_submit()

    conn =
      conn
      |> log_in_user(user, tenant)

    assert redirected_to(conn) == ~p"/t/acme/uploads"

    conn = Plug.Conn.fetch_session(conn)
    assert Plug.Conn.get_session(conn, :user_id) == user.id
  end

  test "authenticated uploads page requires membership", %{conn: conn} do
    {:ok, %{user: outsider}} =
      Accounts.register_user(%{
        workspace_name: "Beta",
        workspace_slug: "beta",
        name: "Outsider",
        email: "outsider@example.com",
        password: "secret123"
      })

    conn = log_in_user(conn, outsider)

    assert {:error, {:redirect, %{to: "/signin"}}} = live(conn, ~p"/t/acme/uploads")
  end
end
