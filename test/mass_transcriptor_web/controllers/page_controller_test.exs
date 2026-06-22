defmodule MassTranscriptorWeb.RedirectControllerTest do
  use MassTranscriptorWeb.ConnCase

  test "GET / redirects to sign in", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/signin"
  end
end
