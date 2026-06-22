defmodule MassTranscriptorWeb.SettingsLiveTest do
  use MassTranscriptorWeb.LiveCase, async: false

  alias MassTranscriptor.Accounts

  setup %{conn: conn} do
    original_api_key = Application.get_env(:mass_transcriptor, :assemblyai_api_key)

    on_exit(fn ->
      Application.put_env(:mass_transcriptor, :assemblyai_api_key, original_api_key)
    end)

    Application.put_env(:mass_transcriptor, :assemblyai_credits_fetcher, fn _api_key ->
      %{
        status: "not_configured",
        balance_usd: nil,
        message: nil,
        dashboard_url: "https://www.assemblyai.com/dashboard/account/billing"
      }
    end)

    on_exit(fn -> Application.delete_env(:mass_transcriptor, :assemblyai_credits_fetcher) end)

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

  test "renders provider settings form", %{conn: conn, tenant: tenant} do
    Application.put_env(:mass_transcriptor, :assemblyai_api_key, nil)

    {:ok, view, html} = live(conn, ~p"/t/#{tenant.slug}/settings")

    assert html =~ "Provider Settings"
    assert html =~ "Choose which engine runs each transcript"
    assert has_element?(view, "#settings-form")
    assert has_element?(view, "#settings-workspace-name")
    assert has_element?(view, "#settings-default-provider")
    assert has_element?(view, "#settings-whisper-language")
    assert html =~ "Missing"
  end

  test "saves provider settings", %{conn: conn, tenant: tenant} do
    Application.put_env(:mass_transcriptor, :assemblyai_api_key, "server-api-key")

    Application.put_env(:mass_transcriptor, :assemblyai_credits_fetcher, fn "server-api-key" ->
      %{
        status: "available",
        balance_usd: 12.34,
        message: nil,
        dashboard_url: "https://www.assemblyai.com/dashboard/account/billing"
      }
    end)

    {:ok, view, _html} = live(conn, ~p"/t/#{tenant.slug}/settings")

    html =
      view
      |> form("#settings-form", %{
        "settings" => %{
          "workspace_name" => "Acme Studio",
          "default_provider" => "assemblyai",
          "whisper_language" => "pt"
        }
      })
      |> render_submit()

    assert html =~ "Settings saved"
    assert html =~ "Acme Studio"
    assert html =~ "$12.34"
    assert has_element?(view, "#flash-info.flash-toast--info")
  end
end
