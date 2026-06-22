defmodule MassTranscriptorWeb.UploadFormats do
  @moduledoc false

  use Gettext, backend: MassTranscriptorWeb.Gettext

  @extensions ~w(
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

  def extensions, do: @extensions

  def hint do
    "MP3, WAV, OGG, M4A, FLAC and more"
  end

  def error_message do
    gettext(
      "This file type is not supported. Use common audio formats such as OGG, MP3, WAV, or M4A."
    )
  end
end
