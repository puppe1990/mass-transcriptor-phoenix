defmodule MassTranscriptor.Accounts do
  @moduledoc false

  import Ecto.Query, warn: false

  alias MassTranscriptor.Accounts.{Membership, Tenant, User}
  alias MassTranscriptor.Repo

  def normalize_slug(slug) when is_binary(slug) do
    slug |> String.trim() |> String.downcase()
  end

  def normalize_email(email) when is_binary(email) do
    email |> String.trim() |> String.downcase()
  end

  def register_user(attrs) do
    with {:ok, tenant} <- create_tenant(attrs),
         {:ok, user} <- create_user(attrs),
         {:ok, membership} <- create_membership(tenant, user) do
      {:ok, %{user: user, tenant: tenant, membership: membership}}
    end
  end

  def authenticate_user(email, password) when is_binary(email) and is_binary(password) do
    email = normalize_email(email)

    with %User{} = user <- get_user_by_email(email),
         true <- Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: normalize_email(email))
  end

  def get_tenant_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Tenant, slug: normalize_slug(slug))
  end

  def list_memberships_for_user(user_id) do
    Membership
    |> where([m], m.user_id == ^user_id)
    |> preload(:tenant)
    |> Repo.all()
  end

  def user_has_membership?(user_id, tenant_id) do
    Membership
    |> where([m], m.user_id == ^user_id and m.tenant_id == ^tenant_id)
    |> Repo.exists?()
  end

  defp create_tenant(attrs) do
    %Tenant{}
    |> Tenant.changeset(%{
      name: attrs[:workspace_name] || attrs["workspace_name"],
      slug: attrs[:workspace_slug] || attrs["workspace_slug"]
    })
    |> Repo.insert()
  end

  defp create_user(attrs) do
    email =
      attrs
      |> Map.get(:email, Map.get(attrs, "email"))
      |> normalize_email()

    %User{}
    |> User.registration_changeset(%{
      name: attrs[:name] || attrs["name"],
      email: email,
      password: attrs[:password] || attrs["password"]
    })
    |> Repo.insert()
  end

  defp create_membership(tenant, user) do
    %Membership{}
    |> Membership.changeset(%{tenant_id: tenant.id, user_id: user.id, role: "owner"})
    |> Repo.insert()
  end
end
