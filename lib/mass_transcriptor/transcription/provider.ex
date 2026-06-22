defmodule MassTranscriptor.Transcription.Provider do
  @moduledoc false

  @type result :: %{
          text: String.t(),
          metadata: map()
        }

  @callback transcribe(file_path :: String.t(), opts :: keyword()) ::
              {:ok, result()} | {:error, String.t()}
end
