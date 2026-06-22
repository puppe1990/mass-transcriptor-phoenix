defmodule MassTranscriptor.Transcription.AssemblyAI do
  @moduledoc false

  @behaviour MassTranscriptor.Transcription.Provider

  @base_url "https://api.assemblyai.com/v2"
  @speech_models ["universal-3-pro", "universal-2"]
  @language_codes ~w(pt en es)

  @impl MassTranscriptor.Transcription.Provider
  def transcribe(file_path, opts) when is_list(opts) do
    api_key = Keyword.fetch!(opts, :api_key)
    language = Keyword.get(opts, :language)
    poll_interval = Keyword.get(opts, :poll_interval, 3_000)
    max_polls = Keyword.get(opts, :max_polls, 60)
    req_options = Keyword.get(opts, :req_options, [])

    with {:ok, upload_url} <- upload_file(file_path, api_key, req_options),
         {:ok, transcript_id} <- create_transcript(upload_url, api_key, language, req_options),
         {:ok, transcript} <-
           poll_transcript(transcript_id, api_key, poll_interval, max_polls, req_options) do
      metadata =
        %{"id" => transcript["id"]}
        |> maybe_put("language_code", transcript["language_code"])

      {:ok, %{text: transcript["text"] || "", metadata: metadata}}
    else
      {:error, message} when is_binary(message) -> {:error, message}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp upload_file(file_path, api_key, req_options) do
    case request!(
           [
             method: :post,
             url: "#{@base_url}/upload",
             headers: auth_headers(api_key),
             body: File.read!(file_path)
           ] ++ req_options
         ) do
      %{"upload_url" => upload_url} -> {:ok, upload_url}
      _ -> {:error, "AssemblyAI upload failed"}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp create_transcript(upload_url, api_key, language, req_options) do
    body =
      %{
        "audio_url" => upload_url,
        "speech_models" => @speech_models
      }
      |> maybe_put_language(language)

    case request!(
           [
             method: :post,
             url: "#{@base_url}/transcript",
             headers: auth_headers(api_key) ++ [{"content-type", "application/json"}],
             json: body
           ] ++ req_options
         ) do
      %{"id" => id} -> {:ok, id}
      _ -> {:error, "AssemblyAI transcript request failed"}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp poll_transcript(transcript_id, api_key, poll_interval, max_polls, req_options) do
    Enum.reduce_while(1..max_polls, {:error, "AssemblyAI transcription timed out"}, fn attempt,
                                                                                       _acc ->
      case request!(
             [
               method: :get,
               url: "#{@base_url}/transcript/#{transcript_id}",
               headers: auth_headers(api_key)
             ] ++ req_options
           ) do
        %{"status" => "completed"} = transcript ->
          {:halt, {:ok, transcript}}

        %{"status" => "error", "error" => message} ->
          {:halt, {:error, message || "AssemblyAI transcription failed"}}

        %{"status" => status} when status in ["queued", "processing"] ->
          if attempt < max_polls, do: sleep(poll_interval)
          {:cont, {:error, "AssemblyAI transcription timed out"}}

        _ ->
          {:halt, {:error, "AssemblyAI transcription failed"}}
      end
    end)
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp maybe_put_language(body, nil), do: Map.put(body, "language_detection", true)

  defp maybe_put_language(body, language) when language in @language_codes do
    Map.put(body, "language_code", language)
  end

  defp maybe_put_language(body, language), do: Map.put(body, "language_code", language)

  defp auth_headers(api_key) do
    [{"authorization", api_key}]
  end

  defp request!(opts) do
    opts
    |> Req.request!()
    |> Map.get(:body)
  end

  defp sleep(0), do: :ok
  defp sleep(ms), do: Process.sleep(ms)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
