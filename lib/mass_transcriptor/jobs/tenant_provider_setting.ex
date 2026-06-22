defmodule MassTranscriptor.Jobs.TenantProviderSetting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenant_provider_settings" do
    field :provider_key, :string
    field :enabled, :boolean, default: true
    field :config_json, :string

    belongs_to :tenant, MassTranscriptor.Accounts.Tenant

    timestamps(type: :utc_datetime)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:tenant_id, :provider_key, :enabled, :config_json])
    |> validate_required([:provider_key, :enabled])
  end
end
