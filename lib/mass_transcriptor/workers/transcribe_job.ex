defmodule MassTranscriptor.Workers.TranscribeJob do
  @moduledoc false

  use Oban.Worker, queue: :transcription, max_attempts: 3

  alias MassTranscriptor.Jobs

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_id" => job_id}}) do
    case Jobs.process_transcription_job(job_id) do
      :ok -> :ok
      {:error, _message} = error -> error
    end
  end
end
