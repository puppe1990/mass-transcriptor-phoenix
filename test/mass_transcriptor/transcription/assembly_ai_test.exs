defmodule MassTranscriptor.Transcription.AssemblyAITest do
  use ExUnit.Case, async: true

  alias MassTranscriptor.Transcription.AssemblyAI

  setup do
    Req.Test.stub(:assemblyai, &handle_request/1)
    :ok
  end

  test "transcribes a local audio file" do
    path = write_temp_audio("sample.wav", "fake-audio")

    assert {:ok, %{text: "Hello world", metadata: metadata}} =
             AssemblyAI.transcribe(path,
               api_key: "test-key",
               poll_interval: 0,
               max_polls: 5,
               req_options: [plug: {Req.Test, :assemblyai}]
             )

    assert metadata["id"] == "tr_123"
    assert metadata["language_code"] == "en"
  end

  test "returns error when transcript fails" do
    Req.Test.stub(:assemblyai, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/v2/upload"} ->
          Req.Test.json(conn, %{"upload_url" => "https://cdn.example.com/audio"})

        {"POST", "/v2/transcript"} ->
          Req.Test.json(conn, %{"id" => "tr_fail", "status" => "queued"})

        {"GET", "/v2/transcript/tr_fail"} ->
          Req.Test.json(conn, %{"status" => "error", "error" => "invalid audio"})
      end
    end)

    path = write_temp_audio("broken.wav", "bad")

    assert {:error, message} =
             AssemblyAI.transcribe(path,
               api_key: "test-key",
               poll_interval: 0,
               max_polls: 3,
               req_options: [plug: {Req.Test, :assemblyai}]
             )

    assert message =~ "invalid audio"
  end

  test "passes language code when provided" do
    Req.Test.stub(:assemblyai, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/v2/upload"} ->
          Req.Test.json(conn, %{"upload_url" => "https://cdn.example.com/audio"})

        {"POST", "/v2/transcript"} ->
          body = conn |> Req.Test.raw_body() |> Jason.decode!()
          assert body["language_code"] == "pt"
          refute Map.has_key?(body, "language_detection")
          Req.Test.json(conn, %{"id" => "tr_pt", "status" => "queued"})

        {"GET", "/v2/transcript/tr_pt"} ->
          Req.Test.json(conn, %{
            "id" => "tr_pt",
            "status" => "completed",
            "text" => "Olá",
            "language_code" => "pt"
          })
      end
    end)

    path = write_temp_audio("sample.ogg", "fake-audio")

    assert {:ok, %{text: "Olá"}} =
             AssemblyAI.transcribe(path,
               api_key: "test-key",
               language: "pt",
               poll_interval: 0,
               max_polls: 5,
               req_options: [plug: {Req.Test, :assemblyai}]
             )
  end

  defp handle_request(conn) do
    case {conn.method, conn.request_path} do
      {"POST", "/v2/upload"} ->
        Req.Test.json(conn, %{"upload_url" => "https://cdn.example.com/audio"})

      {"POST", "/v2/transcript"} ->
        body = conn |> Req.Test.raw_body() |> Jason.decode!()
        assert body["speech_models"] == ["universal-3-pro", "universal-2"]
        assert body["language_detection"] == true
        Req.Test.json(conn, %{"id" => "tr_123", "status" => "queued"})

      {"GET", "/v2/transcript/tr_123"} ->
        Req.Test.json(conn, %{
          "id" => "tr_123",
          "status" => "completed",
          "text" => "Hello world",
          "language_code" => "en"
        })
    end
  end

  defp write_temp_audio(name, content) do
    path = Path.join(System.tmp_dir!(), name)
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
