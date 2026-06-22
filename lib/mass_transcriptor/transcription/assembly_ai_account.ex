defmodule MassTranscriptor.Transcription.AssemblyAIAccount do
  @moduledoc false

  @account_url "https://api.assemblyai.com/v2/account"
  @billing_dashboard_url "https://www.assemblyai.com/dashboard/account/billing"

  @balance_keys ~w(
    balance
    account_balance
    credit_balance
    credits
    remaining_credits
    balance_usd
    available_balance
  )

  def fetch_credits(nil), do: not_configured()
  def fetch_credits(""), do: not_configured()

  def fetch_credits(api_key) when is_binary(api_key) do
    api_key = String.trim(api_key)

    if api_key == "" do
      not_configured()
    else
      do_fetch_credits(api_key)
    end
  end

  defp do_fetch_credits(api_key) do
    case request_account(api_key) do
      {:ok, %{} = payload} ->
        case extract_balance(payload) do
          balance when is_number(balance) ->
            %{
              status: "available",
              balance_usd: balance * 1.0,
              message: nil,
              dashboard_url: @billing_dashboard_url
            }

          _ ->
            %{
              status: "unavailable",
              balance_usd: nil,
              message:
                "AssemblyAI does not expose account balance via API. Open the billing dashboard to see your remaining credits.",
              dashboard_url: @billing_dashboard_url
            }
        end

      {:error, :unauthorized} ->
        %{
          status: "error",
          balance_usd: nil,
          message: "Invalid AssemblyAI API key",
          dashboard_url: @billing_dashboard_url
        }

      {:error, message} when is_binary(message) ->
        %{
          status: "error",
          balance_usd: nil,
          message: message,
          dashboard_url: @billing_dashboard_url
        }
    end
  end

  defp not_configured do
    %{
      status: "not_configured",
      balance_usd: nil,
      message: nil,
      dashboard_url: @billing_dashboard_url
    }
  end

  defp request_account(api_key) do
    opts =
      Application.get_env(:mass_transcriptor, :assemblyai_account_req_options, [])
      |> Keyword.merge(
        method: :get,
        url: @account_url,
        headers: [{"authorization", api_key}],
        receive_timeout: 10_000
      )

    case Req.request(opts) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: status}} ->
        {:error, "AssemblyAI account request failed with status #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp extract_balance(payload) do
    Enum.find_value(@balance_keys, fn key ->
      payload
      |> Map.get(key)
      |> coerce_usd()
    end)
  end

  defp coerce_usd(value) when is_integer(value), do: value * 1.0
  defp coerce_usd(value) when is_float(value), do: value

  defp coerce_usd(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace("$", "")
    |> String.replace(",", "")
    |> case do
      "" -> nil
      stripped -> Float.parse(stripped) |> balance_from_parse()
    end
  end

  defp coerce_usd(_), do: nil

  defp balance_from_parse({balance, ""}), do: balance
  defp balance_from_parse(_), do: nil
end
