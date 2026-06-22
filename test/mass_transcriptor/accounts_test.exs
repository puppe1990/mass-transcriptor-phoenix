defmodule MassTranscriptor.AccountsTest do
  use MassTranscriptor.DataCase, async: false

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Accounts.{Membership, Tenant, User}

  describe "register_user/1" do
    test "creates tenant, user, and owner membership" do
      assert {:ok, %{user: user, tenant: tenant, membership: membership}} =
               Accounts.register_user(%{
                 workspace_name: "Acme",
                 workspace_slug: "acme",
                 name: "Owner",
                 email: "owner@example.com",
                 password: "secret123"
               })

      assert user.email == "owner@example.com"
      assert tenant.slug == "acme"
      assert tenant.name == "Acme"
      assert tenant.default_provider == "assemblyai"
      assert membership.role == "owner"
      assert membership.user_id == user.id
      assert membership.tenant_id == tenant.id
    end

    test "normalizes workspace slug" do
      assert {:ok, %{tenant: tenant}} =
               Accounts.register_user(%{
                 workspace_name: "Acme",
                 workspace_slug: "  ACME  ",
                 name: "Owner",
                 email: "owner@example.com",
                 password: "secret123"
               })

      assert tenant.slug == "acme"
    end

    test "rejects duplicate email" do
      attrs = %{
        workspace_name: "Acme",
        workspace_slug: "acme",
        name: "Owner",
        email: "owner@example.com",
        password: "secret123"
      }

      assert {:ok, _} = Accounts.register_user(attrs)

      assert {:error, changeset} =
               Accounts.register_user(%{attrs | workspace_slug: "beta", workspace_name: "Beta"})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "rejects duplicate workspace slug" do
      attrs = %{
        workspace_name: "Acme",
        workspace_slug: "acme",
        name: "Owner",
        email: "owner@example.com",
        password: "secret123"
      }

      assert {:ok, _} = Accounts.register_user(attrs)

      assert {:error, changeset} =
               Accounts.register_user(%{attrs | email: "other@example.com", name: "Other"})

      assert "has already been taken" in errors_on(changeset).slug
    end
  end

  describe "authenticate_user/2" do
    setup do
      {:ok, %{user: user}} =
        Accounts.register_user(%{
          workspace_name: "Acme",
          workspace_slug: "acme",
          name: "Owner",
          email: "owner@example.com",
          password: "secret123"
        })

      %{user: user}
    end

    test "returns user for valid credentials", %{user: user} do
      assert {:ok, authenticated} = Accounts.authenticate_user("owner@example.com", "secret123")
      assert authenticated.id == user.id
    end

    test "rejects invalid password" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("owner@example.com", "wrong")
    end

    test "rejects unknown email" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("missing@example.com", "secret123")
    end
  end

  describe "get_user_by_email/1" do
    test "returns user when present" do
      {:ok, %{user: user}} =
        Accounts.register_user(%{
          workspace_name: "Acme",
          workspace_slug: "acme",
          name: "Owner",
          email: "owner@example.com",
          password: "secret123"
        })

      assert %User{id: id} = Accounts.get_user_by_email("owner@example.com")
      assert id == user.id
    end

    test "returns nil when missing" do
      refute Accounts.get_user_by_email("missing@example.com")
    end
  end

  describe "list_memberships_for_user/1" do
    test "returns memberships with tenant preloaded" do
      {:ok, %{user: user, tenant: tenant}} =
        Accounts.register_user(%{
          workspace_name: "Acme",
          workspace_slug: "acme",
          name: "Owner",
          email: "owner@example.com",
          password: "secret123"
        })

      assert [%Membership{tenant: %Tenant{slug: "acme"}} = membership] =
               Accounts.list_memberships_for_user(user.id)

      assert membership.tenant_id == tenant.id
    end
  end

  describe "get_tenant_by_slug/1" do
    test "normalizes slug before lookup" do
      {:ok, %{tenant: tenant}} =
        Accounts.register_user(%{
          workspace_name: "Acme",
          workspace_slug: "acme",
          name: "Owner",
          email: "owner@example.com",
          password: "secret123"
        })

      assert %Tenant{id: id} = Accounts.get_tenant_by_slug("  ACME ")
      assert id == tenant.id
    end
  end

  describe "user_has_membership?/2" do
    test "returns true for member" do
      {:ok, %{user: user, tenant: tenant}} =
        Accounts.register_user(%{
          workspace_name: "Acme",
          workspace_slug: "acme",
          name: "Owner",
          email: "owner@example.com",
          password: "secret123"
        })

      assert Accounts.user_has_membership?(user.id, tenant.id)
    end

    test "returns false for outsider" do
      {:ok, %{tenant: tenant}} =
        Accounts.register_user(%{
          workspace_name: "Acme",
          workspace_slug: "acme",
          name: "Owner",
          email: "owner@example.com",
          password: "secret123"
        })

      {:ok, %{user: outsider}} =
        Accounts.register_user(%{
          workspace_name: "Beta",
          workspace_slug: "beta",
          name: "Outsider",
          email: "outsider@example.com",
          password: "secret123"
        })

      refute Accounts.user_has_membership?(outsider.id, tenant.id)
    end
  end
end
