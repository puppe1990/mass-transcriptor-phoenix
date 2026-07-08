defmodule MassTranscriptor.Workers.ConvertVideoJob do
  @moduledoc false

  use Oban.Worker, queue: :convert, max_attempts: 3

  alias MassTranscriptor.Jobs

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"upload_id" => upload_id}}) do
    case Jobs.process_video_conversion(upload_id) do
      :ok -> :ok
      {:error, _message} = error -> error
    end
  end
end