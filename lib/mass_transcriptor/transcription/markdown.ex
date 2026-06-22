defmodule MassTranscriptor.Transcription.Markdown do
  @moduledoc false

  def render(transcript_text, filename, provider) do
    [
      "# Transcript",
      "",
      "- Source: #{filename}",
      "- Provider: #{provider}",
      "",
      String.trim(transcript_text),
      ""
    ]
    |> Enum.join("\n")
  end
end
