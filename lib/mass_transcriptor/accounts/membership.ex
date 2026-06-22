defmodule MassTranscriptor.Accounts.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenant_memberships" do
    field :role, :string, default: "owner"

    belongs_to :tenant, MassTranscriptor.Accounts.Tenant
    belongs_to :user, MassTranscriptor.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:tenant_id, :user_id, :role])
    |> validate_required([:tenant_id, :user_id, :role])
  end
end
