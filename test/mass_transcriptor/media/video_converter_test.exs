defmodule MassTranscriptor.Media.VideoConverterTest do
  use ExUnit.Case, async: true

  alias MassTranscriptor.Media.VideoConverter

  test "validate_duration rejects videos longer than 15 minutes" do
    assert :ok = VideoConverter.validate_duration(60)
    assert {:error, "Video is longer than 15 minutes"} = VideoConverter.validate_duration(901)
  end

  @tag :ffmpeg
  test "to_mp3 converts a short video when ffmpeg is available" do
    if VideoConverter.available?() do
      source = write_fixture_video()

      assert {:ok, mp3_path} = VideoConverter.to_mp3(source)
      assert File.exists?(mp3_path)
      assert File.stat!(mp3_path).size > 0

      File.rm!(source)
      File.rm!(mp3_path)
    else
      assert {:error, message} = VideoConverter.to_mp3("/tmp/missing.mp4")
      assert message =~ "ffmpeg"
    end
  end

  defp write_fixture_video do
    path = Path.join(System.tmp_dir!(), "fixture-#{System.unique_integer([:positive])}.mp4")

    {_, 0} =
      System.cmd("ffmpeg", [
        "-f",
        "lavfi",
        "-i",
        "sine=frequency=440:duration=1",
        "-f",
        "lavfi",
        "-i",
        "color=c=black:s=64x64:d=1",
        "-shortest",
        "-y",
        path
      ])

    path
  end
end