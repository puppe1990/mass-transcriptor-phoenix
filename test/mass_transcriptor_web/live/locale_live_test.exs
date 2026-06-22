defmodule MassTranscriptorWeb.LocaleLiveTest do
  use MassTranscriptorWeb.LiveCase, async: false

  alias MassTranscriptor.Accounts

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

  test "change locale updates selection on jobs page", %{conn: conn, tenant: tenant} do
    {:ok, view, _html} = live(conn, ~p"/t/#{tenant.slug}/jobs")

    assert has_element?(view, "#locale-select option[value=\"en\"][selected]")

    view
    |> form("#locale-form", %{locale: "pt_BR"})
    |> render_change()

    assert has_element?(view, "#locale-select option[value=\"pt_BR\"][selected]")
    refute has_element?(view, "#locale-select option[value=\"en\"][selected]")
  end

  test "change locale updates selection on uploads page", %{conn: conn, tenant: tenant} do
    {:ok, view, _html} = live(conn, ~p"/t/#{tenant.slug}/uploads")

    view
    |> form("#locale-form", %{locale: "pt_BR"})
    |> render_change()

    assert has_element?(view, "#locale-select option[value=\"pt_BR\"][selected]")
  end

  test "change locale updates selection on settings page", %{conn: conn, tenant: tenant} do
    {:ok, view, _html} = live(conn, ~p"/t/#{tenant.slug}/settings")

    view
    |> form("#locale-form", %{locale: "pt_BR"})
    |> render_change()

    assert has_element?(view, "#locale-select option[value=\"pt_BR\"][selected]")
  end
end
