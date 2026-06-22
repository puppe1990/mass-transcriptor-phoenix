defmodule MassTranscriptor.SettingsTest do
  use MassTranscriptor.DataCase, async: false

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Repo
  alias MassTranscriptor.Settings

  setup do
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

    {:ok, %{tenant: tenant}} =
      Accounts.register_user(%{
        workspace_name: "Acme",
        workspace_slug: "acme",
        name: "Owner",
        email: "owner@example.com",
        password: "secret123"
      })

    %{tenant: tenant}
  end

  test "get_provider_settings/1 returns workspace defaults", %{tenant: tenant} do
    Application.put_env(:mass_transcriptor, :assemblyai_api_key, nil)

    settings = Settings.get_provider_settings(tenant)

    assert settings.workspace_name == "Acme"
    assert settings.default_provider == "assemblyai"
    assert settings.whisper_language == "auto"
    assert settings.providers.assemblyai.has_api_key == false
    assert settings.assemblyai_credits.status == "not_configured"
  end

  test "get_provider_settings/1 reflects configured assemblyai key", %{tenant: tenant} do
    Application.put_env(:mass_transcriptor, :assemblyai_api_key, "server-api-key")

    Application.put_env(:mass_transcriptor, :assemblyai_credits_fetcher, fn "server-api-key" ->
      %{
        status: "available",
        balance_usd: 12.34,
        message: nil,
        dashboard_url: "https://www.assemblyai.com/dashboard/account/billing"
      }
    end)

    settings = Settings.get_provider_settings(tenant)

    assert settings.providers.assemblyai.has_api_key == true
    assert settings.assemblyai_credits.balance_usd == 12.34
  end

  test "update_provider_settings/2 updates tenant and whisper language", %{tenant: tenant} do
    Application.put_env(:mass_transcriptor, :assemblyai_api_key, "server-api-key")

    assert {:ok, settings} =
             Settings.update_provider_settings(tenant, %{
               "workspace_name" => "Acme Audio Lab",
               "default_provider" => "assemblyai",
               "whisper_language" => "pt"
             })

    assert settings.workspace_name == "Acme Audio Lab"
    assert settings.default_provider == "assemblyai"
    assert settings.whisper_language == "pt"

    tenant = Repo.get!(MassTranscriptor.Accounts.Tenant, tenant.id)
    assert tenant.name == "Acme Audio Lab"
    assert tenant.default_provider == "assemblyai"
  end

  test "update_provider_settings/2 rejects assemblyai without server key", %{tenant: tenant} do
    Application.put_env(:mass_transcriptor, :assemblyai_api_key, nil)

    assert {:error, changeset} =
             Settings.update_provider_settings(tenant, %{
               "workspace_name" => "Acme",
               "default_provider" => "assemblyai",
               "whisper_language" => "auto"
             })

    assert "AssemblyAI requires ASSEMBLYAI_API_KEY to be configured on the server" in errors_on(
             changeset
           ).default_provider
  end

  test "update_provider_settings/2 rejects unsupported whisper language", %{tenant: tenant} do
    assert {:error, changeset} =
             Settings.update_provider_settings(tenant, %{
               "workspace_name" => "Acme",
               "default_provider" => "whisper",
               "whisper_language" => "fr"
             })

    assert "is invalid" in errors_on(changeset).whisper_language
  end
end
