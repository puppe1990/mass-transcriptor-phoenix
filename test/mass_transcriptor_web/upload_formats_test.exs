defmodule MassTranscriptorWeb.UploadFormatsTest do
  use ExUnit.Case, async: true

  alias MassTranscriptorWeb.UploadFormats

  test "accepts common audio and video extensions" do
    assert ".mp3" in UploadFormats.extensions()
    assert ".mp4" in UploadFormats.extensions()
    assert ".mov" in UploadFormats.extensions()
    assert ".mkv" in UploadFormats.extensions()
  end

  test "video?/2 detects video by extension or mime type" do
    assert UploadFormats.video?("clip.mp4")
    assert UploadFormats.video?("clip.MOV")
    refute UploadFormats.video?("clip.mp3")
    assert UploadFormats.video?("clip.bin", "video/webm")
    refute UploadFormats.video?("clip.bin", "audio/webm")
  end

  test "max video limits" do
    assert UploadFormats.max_video_bytes() == 25_000_000
    assert UploadFormats.max_video_duration_seconds() == 900
  end
end