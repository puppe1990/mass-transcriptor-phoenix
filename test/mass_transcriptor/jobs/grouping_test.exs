defmodule MassTranscriptor.Jobs.GroupingTest do
  use ExUnit.Case, async: true

  alias MassTranscriptor.Jobs.Grouping

  defp job(attrs) do
    %{
      id: Map.fetch!(attrs, :id),
      status: Map.get(attrs, :status, "queued"),
      provider_key: Map.get(attrs, :provider_key, "assemblyai"),
      batch_id: Map.get(attrs, :batch_id),
      upload_id: Map.get(attrs, :upload_id, Map.fetch!(attrs, :id)),
      original_filename: Map.get(attrs, :original_filename, "file-#{attrs.id}.wav"),
      created_at: Map.get(attrs, :created_at, ~U[2026-06-15 12:00:00Z])
    }
  end

  test "build_job_list_rows/1 groups jobs with the same batch id" do
    rows =
      Grouping.build_job_list_rows([
        job(%{id: 1, batch_id: 9, original_filename: "a.wav"}),
        job(%{id: 2, batch_id: 9, original_filename: "b.wav"}),
        job(%{id: 3, original_filename: "solo.wav"})
      ])

    assert length(rows) == 2

    batch_row = Enum.find(rows, &(&1.kind == :batch))
    assert batch_row[:batch_id] == 9
    assert Enum.map(batch_row[:jobs], & &1.original_filename) |> Enum.sort() == ["a.wav", "b.wav"]

    single_row = Enum.find(rows, &(&1.kind == :single))
    assert single_row[:job].original_filename == "solo.wav"
  end

  test "summarize_batch_status/1 prefers failed and in-progress states" do
    assert Grouping.summarize_batch_status([
             job(%{id: 1, status: "completed"}),
             job(%{id: 2, status: "failed"})
           ]) == "failed"

    assert Grouping.summarize_batch_status([
             job(%{id: 1, status: "completed"}),
             job(%{id: 2, status: "processing"})
           ]) == "processing"
  end
end
