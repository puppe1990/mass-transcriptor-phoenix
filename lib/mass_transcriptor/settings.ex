defmodule MassTranscriptor.Settings do
  @moduledoc false

  import Ecto.Query, warn: false

  alias MassTranscriptor.Accounts.Tenant
  alias MassTranscriptor.Jobs.TenantProviderSetting
  alias MassTranscriptor.Repo
  alias MassTranscriptor.Transcription.AssemblyAIAccount

  @allowed_whisper_languages ~w(auto pt en es)
  @allowed_providers ~w(whisper assemblyai)

  defmodule ProviderSettings do
    @moduledoc false
    defstruct [
      :workspace_name,
      :default_provider,
      :whisper_language,
      :providers,
      :assemblyai_credits
    ]
  end

  def get_provider_settings(%Tenant{} = tenant) do
    api_key = assemblyai_api_key()
    has_api_key = api_key not in [nil, ""]

    %ProviderSettings{
      workspace_name: tenant.name,
      default_provider: tenant.default_provider,
      whisper_language: resolve_whisper_language(tenant.id),
      providers: %{
        whisper: %{enabled: true, has_api_key: false},
        assemblyai: %{enabled: has_api_key, has_api_key: has_api_key}
      },
      assemblyai_credits: credits_fetcher().(api_key)
    }
  end

  def update_provider_settings(%Tenant{} = tenant, attrs) when is_map(attrs) do
    changeset = settings_changeset(tenant, attrs)

    with {:ok, validated} <- apply_action(changeset, :update),
         :ok <- validate_assemblyai_provider(validated),
         {:ok, tenant} <- update_tenant(tenant, validated),
         :ok <- upsert_whisper_setting(tenant.id, validated.whisper_language) do
      {:ok, get_provider_settings(tenant)}
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      {:error, message} -> {:error, error_changeset(tenant, attrs, :default_provider, message)}
    end
  end

  def resolve_whisper_language(tenant_id) do
    case Repo.get_by(TenantProviderSetting, tenant_id: tenant_id, provider_key: "whisper") do
      nil ->
        "auto"

      %{config_json: json} ->
        with {:ok, %{"language" => language}} <- Jason.decode(json || "{}"),
             true <- language in @allowed_whisper_languages do
          language
        else
          _ -> "auto"
        end
    end
  end

  def change_settings(%Tenant{} = tenant, attrs \\ %{}) do
    settings_changeset(tenant, attrs)
  end

  defp settings_changeset(%Tenant{} = tenant, attrs) do
    data = %{
      workspace_name: tenant.name,
      default_provider: tenant.default_provider,
      whisper_language: resolve_whisper_language(tenant.id)
    }

    types = %{
      workspace_name: :string,
      default_provider: :string,
      whisper_language: :string
    }

    {data, types}
    |> Ecto.Changeset.cast(attrs, Map.keys(types))
    |> Ecto.Changeset.validate_required([:workspace_name, :default_provider, :whisper_language])
    |> Ecto.Changeset.update_change(:workspace_name, &String.trim/1)
    |> Ecto.Changeset.update_change(:default_provider, &String.downcase(String.trim(&1)))
    |> Ecto.Changeset.update_change(:whisper_language, &String.downcase(String.trim(&1)))
    |> Ecto.Changeset.validate_inclusion(:default_provider, @allowed_providers)
    |> Ecto.Changeset.validate_inclusion(:whisper_language, @allowed_whisper_languages)
    |> Ecto.Changeset.validate_length(:workspace_name, min: 1)
  end

  defp apply_action(changeset, action) do
    case Ecto.Changeset.apply_action(changeset, action) do
      {:ok, settings} -> {:ok, settings}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp validate_assemblyai_provider(%{default_provider: "assemblyai"}) do
    if assemblyai_api_key() in [nil, ""] do
      {:error, "AssemblyAI requires ASSEMBLYAI_API_KEY to be configured on the server"}
    else
      :ok
    end
  end

  defp validate_assemblyai_provider(_settings), do: :ok

  defp update_tenant(tenant, settings) do
    tenant
    |> Tenant.changeset(%{
      name: settings.workspace_name,
      default_provider: settings.default_provider
    })
    |> Repo.update()
  end

  defp upsert_whisper_setting(tenant_id, language) do
    config_json = Jason.encode!(%{"language" => language})

    case Repo.get_by(TenantProviderSetting, tenant_id: tenant_id, provider_key: "whisper") do
      nil ->
        %TenantProviderSetting{}
        |> TenantProviderSetting.changeset(%{
          tenant_id: tenant_id,
          provider_key: "whisper",
          enabled: true,
          config_json: config_json
        })
        |> Repo.insert()

      setting ->
        setting
        |> TenantProviderSetting.changeset(%{enabled: true, config_json: config_json})
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp error_changeset(tenant, attrs, field, message) do
    tenant
    |> change_settings(attrs)
    |> Ecto.Changeset.add_error(field, message)
  end

  defp assemblyai_api_key do
    Application.get_env(:mass_transcriptor, :assemblyai_api_key)
    |> case do
      key when is_binary(key) ->
        trimmed = String.trim(key)
        if trimmed == "", do: nil, else: trimmed

      _ ->
        nil
    end
  end

  defp credits_fetcher do
    Application.get_env(
      :mass_transcriptor,
      :assemblyai_credits_fetcher,
      &AssemblyAIAccount.fetch_credits/1
    )
  end
end
