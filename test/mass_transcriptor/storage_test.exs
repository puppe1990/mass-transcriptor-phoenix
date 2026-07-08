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

  test "streams source video from temp path without loading into memory" do
    temp = Path.join(System.tmp_dir!(), "video-source-#{System.unique_integer([:positive])}.mp4")
    File.write!(temp, "fake-video")

    path = Storage.write_source_from_path("acme", 99, "clip.mp4", temp)

    assert String.ends_with?(path, "acme/uploads/99/source/clip.mp4")
    assert File.read!(path) == "fake-video"
    File.rm!(temp)
  end

  test "cleanup_upload_media removes source and audio directories" do
    source = Storage.write_source_from_path("acme", 55, "clip.mp4", write_temp("video"))
    audio = Storage.write_audio("acme", 55, "clip.mp3", "fake-audio")

    assert File.exists?(source)
    assert File.exists?(audio)

    :ok = Storage.cleanup_upload_media("acme", 55)

    refute File.exists?(Path.dirname(source))
    refute File.exists?(Path.dirname(audio))
  end

  defp write_temp(content) do
    path = Path.join(System.tmp_dir!(), "tmp-#{System.unique_integer([:positive])}")
    File.write!(path, content)
    path
  end
end
