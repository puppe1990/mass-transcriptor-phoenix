defmodule MassTranscriptor.Accounts.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenants" do
    field :slug, :string
    field :name, :string
    field :default_provider, :string, default: "assemblyai"

    has_many :memberships, MassTranscriptor.Accounts.Membership

    timestamps(type: :utc_datetime)
  end

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:slug, :name, :default_provider])
    |> validate_required([:slug, :name])
    |> update_change(:slug, &MassTranscriptor.Accounts.normalize_slug/1)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
    |> unique_constraint(:slug)
  end
end
