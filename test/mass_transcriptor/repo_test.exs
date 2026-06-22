defmodule MassTranscriptor.RepoTest do
  use MassTranscriptor.DataCase, async: false

  alias MassTranscriptor.Repo

  test "connects to the configured libsql database" do
    assert %{rows: [[1]]} = Ecto.Adapters.SQL.query!(Repo, "SELECT 1")
  end
end
