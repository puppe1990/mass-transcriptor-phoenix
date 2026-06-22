defmodule MassTranscriptorWeb.LocaleHook do
  @moduledoc false

  import Phoenix.Component
  import Phoenix.LiveView

  @supported_locales ~w(en pt_BR)

  def on_mount(:default, _params, session, socket) do
    locale = normalize_locale(session["locale"])

    Gettext.put_locale(MassTranscriptorWeb.Gettext, locale)

    socket =
      socket
      |> assign(:locale, locale)
      |> attach_hook(:locale, :handle_event, &handle_event/3)

    {:cont, socket}
  end

  defp handle_event("change_locale", %{"locale" => locale}, socket) do
    locale = normalize_locale(locale)
    Gettext.put_locale(MassTranscriptorWeb.Gettext, locale)

    {:halt, assign(socket, :locale, locale)}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}

  defp normalize_locale(locale) when locale in @supported_locales, do: locale
  defp normalize_locale(_), do: "en"
end
