defmodule MassTranscriptor.StorageTest do
  use MassTranscriptor.DataCase, async: false

  alias MassTranscriptor.Storage

  test "scopes audio files under tenant upload directory" do
    path = Storage.write_audio("acme", 42, "sample.wav", "fake-audio")

    assert String.ends_with?(path, "acme/uploads/42/audio/sample.wav")
    assert File.read!(path) == "fake-audio"
  end

  test "writes markdown transcript path" do
    path = Storage.write_markdown("acme", 7, "# transcript")

    assert String.ends_with?(path, "acme/uploads/7/transcript/transcript.md")
    assert File.read!(path) == "# transcript"
  end
end
