defmodule MassTranscriptor.Media.VideoConverter do
  @moduledoc false

  alias MassTranscriptorWeb.UploadFormats

  @ffmpeg_timeout_ms :timer.minutes(10)

  def available? do
    not is_nil(System.find_executable("ffmpeg")) and not is_nil(System.find_executable("ffprobe"))
  end

  def to_mp3(source_path) when is_binary(source_path) do
    with :ok <- ensure_available(),
         {:ok, duration} <- probe_duration(source_path),
         :ok <- validate_duration(duration),
         {:ok, output_path} <- convert(source_path) do
      {:ok, output_path}
    end
  end

  def probe_duration(source_path) when is_binary(source_path) do
    with :ok <- ensure_available(),
         {output, 0} <-
           run_ffprobe([
             "-v",
             "error",
             "-show_entries",
             "format=duration",
             "-of",
             "default=noprint_wrappers=1:nokey=1",
             source_path
           ]) do
      case Float.parse(String.trim(output)) do
        {duration, _} when duration > 0 -> {:ok, duration}
        _ -> {:error, "Could not read video duration"}
      end
    else
      {_output, _code} -> {:error, "Could not read video duration"}
      {:error, message} -> {:error, message}
    end
  end

  def validate_duration(duration) when is_number(duration) do
    if duration <= UploadFormats.max_video_duration_seconds() do
      :ok
    else
      {:error, "Video is longer than 15 minutes"}
    end
  end

  defp convert(source_path) do
    output_path =
      Path.join(
        System.tmp_dir!(),
        "mass-transcriptor-#{:erlang.unique_integer([:positive])}.mp3"
      )

    case run_ffmpeg([
           "-i",
           source_path,
           "-vn",
           "-ac",
           "1",
           "-ar",
           "16000",
           "-b:a",
           "64k",
           "-y",
           output_path
         ]) do
      {_, 0} ->
        {:ok, output_path}

      {output, _code} ->
        {:error, friendly_error(output)}
    end
  end

  defp ensure_available do
    if available?() do
      :ok
    else
      {:error, "Video conversion requires ffmpeg and ffprobe on the server"}
    end
  end

  defp friendly_error(output) do
    cond do
      String.contains?(output, "does not contain any stream") ->
        "Video file has no audio track"

      String.contains?(output, "Invalid data") ->
        "Video file is invalid or corrupted"

      true ->
        "Video conversion failed"
    end
  end

  defp run_ffmpeg(args) do
    System.cmd("ffmpeg", args, stderr_to_stdout: true, timeout: @ffmpeg_timeout_ms)
  end

  defp run_ffprobe(args) do
    System.cmd("ffprobe", args, stderr_to_stdout: true, timeout: 30_000)
  end
end