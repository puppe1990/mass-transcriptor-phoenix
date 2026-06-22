defmodule MassTranscriptorWeb.LiveCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  import Phoenix.ConnTest

  use MassTranscriptorWeb, :verified_routes

  @endpoint MassTranscriptorWeb.Endpoint

  using do
    quote do
      @endpoint MassTranscriptorWeb.Endpoint

      use MassTranscriptorWeb, :verified_routes
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      import MassTranscriptorWeb.LiveCase
    end
  end

  setup tags do
    MassTranscriptor.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def log_in_user(conn, user, tenant \\ nil) do
    return_to =
      if tenant do
        ~p"/t/#{tenant.slug}/uploads"
      else
        ~p"/signin"
      end

    token = Phoenix.Token.sign(MassTranscriptorWeb.Endpoint, "user session", user.id)

    get(conn, ~p"/session?#{%{token: token, return_to: return_to}}")
  end
end
