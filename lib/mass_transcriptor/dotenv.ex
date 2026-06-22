defmodule MassTranscriptor.Dotenv do
  @moduledoc false

  @doc """
  Loads simple KEY=value lines from a `.env` file into the process environment.
  Existing variables are left unchanged.
  """
  def load(path) when is_binary(path) do
    if File.exists?(path) do
      path
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.each(&put_line/1)
    end

    :ok
  end

  defp put_line(line) do
    case String.split(line, "=", parts: 2) do
      [key, value] ->
        key = String.trim(key)

        if key != "" and System.get_env(key) in [nil, ""] do
          System.put_env(key, String.trim(value))
        end

      _ ->
        :ok
    end
  end
end
