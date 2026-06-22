defmodule MassTranscriptor.RepoTest do
  use MassTranscriptor.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias MassTranscriptor.Repo

  test "connects to the configured libsql database" do
    assert %{rows: [[1]]} = SQL.query!(Repo, "SELECT 1")
  end
end
