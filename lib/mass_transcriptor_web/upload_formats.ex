defmodule MassTranscriptorWeb.UploadFormats do
  @moduledoc false

  use Gettext, backend: MassTranscriptorWeb.Gettext

  @audio_extensions ~w(
    .wav
    .mp3
    .ogg
    .opus
    .m4a
    .flac
    .webm
    .aac
    .wma
    .mpga
    .oga
  )

  @video_extensions ~w(.mp4 .mov .mkv)

  @max_video_bytes 25_000_000
  @max_video_duration_seconds 15 * 60

  def audio_extensions, do: @audio_extensions
  def video_extensions, do: @video_extensions
  def extensions, do: @audio_extensions ++ @video_extensions
  def max_video_bytes, do: @max_video_bytes
  def max_video_duration_seconds, do: @max_video_duration_seconds

  def video?(filename) when is_binary(filename) do
    video?(filename, nil)
  end

  def video?(filename, mime_type) when is_binary(filename) do
    extension_video?(filename) or video_mime?(mime_type)
  end

  def video?(_), do: false

  def hint do
    "MP3, WAV, OGG, M4A, FLAC or MP4, MOV, WebM, MKV (video up to 25 MB)"
  end

  def error_message do
    gettext(
      "This file type is not supported. Use common audio formats or MP4, MOV, WebM, and MKV video."
    )
  end

  def video_too_large_message(name) do
    gettext("%{name} is too large. Video files must be 25 MB or smaller.", name: name)
  end

  defp extension_video?(filename) do
    filename
    |> Path.extname()
    |> String.downcase()
    |> then(&(&1 in @video_extensions))
  end

  defp video_mime?(mime) when is_binary(mime), do: String.starts_with?(mime, "video/")
  defp video_mime?(_), do: false
end