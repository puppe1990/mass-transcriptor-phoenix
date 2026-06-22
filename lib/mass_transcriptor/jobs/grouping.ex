defmodule MassTranscriptor.Jobs.Grouping do
  @moduledoc false

  def build_job_list_rows(jobs) when is_list(jobs) do
    {batches, singles} =
      Enum.reduce(jobs, {%{}, []}, fn job, {batches, singles} ->
        case job.batch_id do
          nil -> {batches, [job | singles]}
          batch_id -> {Map.update(batches, batch_id, [job], &[job | &1]), singles}
        end
      end)

    batch_rows =
      Enum.map(batches, fn {batch_id, batch_jobs} ->
        sorted =
          Enum.sort_by(batch_jobs, & &1.created_at, {:desc, DateTime})

        %{
          kind: :batch,
          batch_id: batch_id,
          jobs: sorted,
          created_at: hd(sorted).created_at
        }
      end)

    single_rows = Enum.map(singles, &%{kind: :single, job: &1})

    (batch_rows ++ single_rows)
    |> Enum.sort_by(
      fn
        %{kind: :batch, created_at: created_at} -> created_at
        %{kind: :single, job: job} -> job.created_at
      end,
      {:desc, DateTime}
    )
  end

  def summarize_batch_status(jobs) when is_list(jobs) do
    cond do
      Enum.any?(jobs, &(&1.status == "failed")) -> "failed"
      Enum.any?(jobs, &(&1.status == "processing")) -> "processing"
      Enum.any?(jobs, &(&1.status == "queued")) -> "queued"
      true -> "completed"
    end
  end
end
