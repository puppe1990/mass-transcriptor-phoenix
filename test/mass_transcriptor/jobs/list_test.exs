defmodule MassTranscriptor.Jobs.ListTest do
  use MassTranscriptor.DataCase, async: false

  alias MassTranscriptor.Accounts
  alias MassTranscriptor.Jobs
  alias MassTranscriptor.Repo

  setup do
    {:ok, %{tenant: tenant}} =
      Accounts.register_user(%{
        workspace_name: "Acme",
        workspace_slug: "acme",
        name: "Owner",
        email: "owner@example.com",
        password: "secret123"
      })

    %{tenant: tenant}
  end

  test "list_job_summaries_for_tenant/1 returns jobs newest first", %{tenant: tenant} do
    [older] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "older.wav", mime_type: "audio/wav", size: 4, content: "old"}
      ])

    older
    |> Ecto.Changeset.change(%{inserted_at: ~U[2026-06-15 10:00:00Z]})
    |> Repo.update!()

    [newer] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "newer.wav", mime_type: "audio/wav", size: 4, content: "new"}
      ])

    summaries = Jobs.list_job_summaries_for_tenant(tenant.id)

    assert length(summaries) == 2
    assert hd(summaries).id == newer.id
    assert Enum.at(summaries, 1).id == older.id
    assert hd(summaries).original_filename == "newer.wav"
    assert hd(summaries).status == "queued"
  end

  test "list_job_summaries_for_tenant/1 includes error_message", %{tenant: tenant} do
    [job] =
      Jobs.create_uploads_and_jobs(tenant, [
        %{filename: "failed.wav", mime_type: "audio/wav", size: 4, content: "data"}
      ])

    {:error, _} = Jobs.mark_job_failed(Jobs.fetch_job!(job.id), "transcription failed")

    [summary] = Jobs.list_job_summaries_for_tenant(tenant.id)

    assert summary.error_message == "transcription failed"
  end
end
