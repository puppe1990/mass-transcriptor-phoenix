defmodule MassTranscriptorWeb.SettingsLive do
  use MassTranscriptorWeb, :live_view

  alias MassTranscriptor.Settings

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    settings = Settings.get_provider_settings(tenant)
    changeset = Settings.change_settings(tenant)

    {:ok,
     socket
     |> assign(:page_title, gettext("Provider Settings"))
     |> assign(:active_tab, :settings)
     |> assign(:provider_settings, settings)
     |> assign(:save_error, nil)
     |> assign(:form, to_form(changeset, as: :settings))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} tenant_slug={@tenant_slug} active_tab={@active_tab} locale={@locale}>
      <section class="settings-shell">
        <div class="settings-shell__intro">
          <p class="settings-shell__eyebrow">{gettext("Workspace controls")}</p>
          <h1>{gettext("Provider Settings")}</h1>
          <p class="settings-shell__lede">
            {gettext(
              "Choose which engine runs each transcript and keep external credentials scoped to this workspace only."
            )}
          </p>

          <div class="settings-shell__note">
            <p class="settings-shell__label">{gettext("Workspace")}</p>
            <strong>{@provider_settings.workspace_name}</strong>
            <p>{gettext("Slug: %{tenant_slug}", tenant_slug: @tenant_slug)}</p>
            <p>
              {gettext(
                "Whisper runs locally. AssemblyAI uses the server ASSEMBLYAI_API_KEY environment variable."
              )}
            </p>
            <p>
              {gettext(
                "Set ASSEMBLYAI_API_KEY in backend/.env to enable AssemblyAI as the default provider."
              )}
            </p>
          </div>
        </div>

        <div class="settings-card">
          <.form for={@form} id="settings-form" phx-submit="save" phx-change="validate">
            <section class="settings-form__section">
              <p class="settings-shell__label">{gettext("Workspace")}</p>
              <label class="settings-form__field">
                <span>{gettext("Workspace")}</span>
                <input
                  id="settings-workspace-name"
                  type="text"
                  name={@form[:workspace_name].name}
                  value={@form[:workspace_name].value}
                  placeholder={gettext("Your workspace")}
                  aria-label={gettext("Workspace name")}
                />
              </label>
            </section>

            <section class="settings-form__section">
              <p class="settings-shell__label">{gettext("Provider")}</p>
              <label class="settings-form__field">
                <span>{gettext("Default provider")}</span>
                <select
                  id="settings-default-provider"
                  name={@form[:default_provider].name}
                  aria-label={gettext("Default provider")}
                >
                  <option value="whisper" selected={@form[:default_provider].value == "whisper"}>
                    whisper
                  </option>
                  <option
                    value="assemblyai"
                    selected={@form[:default_provider].value == "assemblyai"}
                  >
                    assemblyai
                  </option>
                </select>
              </label>
              <label class="settings-form__field">
                <span>{gettext("Transcription language")}</span>
                <select
                  id="settings-whisper-language"
                  name={@form[:whisper_language].name}
                  aria-label={gettext("Transcription language")}
                >
                  <option value="auto" selected={@form[:whisper_language].value == "auto"}>
                    {gettext("Auto detect")}
                  </option>
                  <option value="pt" selected={@form[:whisper_language].value == "pt"}>
                    {gettext("Portuguese")}
                  </option>
                  <option value="en" selected={@form[:whisper_language].value == "en"}>
                    {gettext("English")}
                  </option>
                  <option value="es" selected={@form[:whisper_language].value == "es"}>
                    {gettext("Spanish")}
                  </option>
                </select>
              </label>
            </section>

            <section class="settings-form__section">
              <p class="settings-shell__label">{gettext("Credentials")}</p>
              <div class="settings-form__status-row">
                <span class="settings-shell__label">{gettext("AssemblyAI server key")}</span>
                <span class={assemblyai_key_status_class(@provider_settings)}>
                  {assemblyai_key_status_label(@provider_settings)}
                </span>
              </div>
              <div
                :if={
                  @provider_settings.providers.assemblyai.has_api_key &&
                    @provider_settings.assemblyai_credits
                }
                class="settings-form__status-row"
              >
                <span class="settings-shell__label">{gettext("AssemblyAI credits")}</span>
                <.assemblyai_credits_badge credits={@provider_settings.assemblyai_credits} />
              </div>
            </section>

            <div class="settings-form__footer">
              <p>
                {gettext(
                  "Changes apply to new uploads. Existing jobs keep the provider they were created with."
                )}
              </p>
              <button type="submit" id="settings-save" phx-disable-with={gettext("Saving...")}>
                {gettext("Save Settings")}
              </button>
            </div>
          </.form>

          <p
            :if={@save_error}
            id="settings-error"
            class="settings-feedback settings-feedback--error"
            role="alert"
          >
            {@save_error}
          </p>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"settings" => params}, socket) do
    changeset =
      socket.assigns.current_tenant
      |> Settings.change_settings(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :settings))}
  end

  def handle_event("save", %{"settings" => params}, socket) do
    tenant = socket.assigns.current_tenant

    case Settings.update_provider_settings(tenant, params) do
      {:ok, settings} ->
        tenant = %{
          tenant
          | name: settings.workspace_name,
            default_provider: settings.default_provider
        }

        changeset = Settings.change_settings(tenant)

        {:noreply,
         socket
         |> assign(:current_tenant, tenant)
         |> assign(:provider_settings, settings)
         |> assign(:save_error, nil)
         |> assign(:form, to_form(changeset, as: :settings))
         |> put_flash(:info, gettext("Settings saved"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:save_error, first_error(changeset))
         |> assign(:form, to_form(changeset, as: :settings))}
    end
  end

  defp assemblyai_key_status_class(settings) do
    if settings.providers.assemblyai.has_api_key do
      "settings-status settings-status--ok"
    else
      "settings-status settings-status--missing"
    end
  end

  defp assemblyai_key_status_label(settings) do
    if settings.providers.assemblyai.has_api_key do
      gettext("Configured")
    else
      gettext("Missing")
    end
  end

  defp first_error(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> List.first()
    |> Kernel.||(gettext("Failed to save settings"))
  end

  attr :credits, :map, required: true

  defp assemblyai_credits_badge(assigns) do
    ~H"""
    <%= cond do %>
      <% @credits.status == "available" and is_number(@credits.balance_usd) -> %>
        <span class="settings-status settings-status--ok">
          {gettext("%{balance} remaining", balance: format_usd(@credits.balance_usd))}
        </span>
      <% @credits.status == "error" -> %>
        <span class="settings-status settings-status--missing">
          {@credits.message || gettext("Could not load credits")}
        </span>
      <% true -> %>
        <span class="settings-status settings-status--neutral">
          {gettext("Balance not available via API")}
          {" · "}
          <a href={@credits.dashboard_url} target="_blank" rel="noreferrer">
            {gettext("Open billing dashboard")}
          </a>
        </span>
    <% end %>
    """
  end

  defp format_usd(amount) do
    :erlang.float_to_binary(amount * 1.0, decimals: 2)
    |> then(&"$#{&1}")
  end
end
