defmodule MassTranscriptor.Transcription.MarkdownTest do
  use ExUnit.Case, async: true

  alias MassTranscriptor.Transcription.Markdown

  test "renders transcript markdown with heading and metadata" do
    output = Markdown.render("hello world", "sample.wav", "assemblyai")

    assert output =~ "# Transcript"
    assert output =~ "sample.wav"
    assert output =~ "assemblyai"
    assert output =~ "hello world"
  end
end
