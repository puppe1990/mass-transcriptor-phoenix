defmodule MassTranscriptorWeb.AuthLive.SignUp do
  use MassTranscriptorWeb, :live_view

  alias MassTranscriptor.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Create Workspace"))
     |> assign(
       :form,
       to_form(
         %{
           "workspace_name" => "",
           "workspace_slug" => "",
           "name" => "",
           "email" => "",
           "password" => ""
         },
         as: :user
       )
     )
     |> assign(:show_password, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth
      flash={@flash}
      eyebrow={gettext("Create workspace")}
      title={gettext("Create Workspace")}
      subtitle={
        gettext("Set up your transcription hub and start turning recordings into clean markdown.")
      }
    >
      <.form for={@form} id="sign-up-form" phx-submit="sign_up" class="auth-form">
        <div class="auth-form__field">
          <label for="user_workspace_name">{gettext("Workspace name")}</label>
          <input
            class="app-control"
            type="text"
            name="user[workspace_name]"
            id="user_workspace_name"
            value={@form[:workspace_name].value}
            required
          />
        </div>

        <div class="auth-form__field">
          <label for="user_workspace_slug">{gettext("Workspace slug")}</label>
          <input
            class="app-control"
            type="text"
            name="user[workspace_slug]"
            id="user_workspace_slug"
            value={@form[:workspace_slug].value}
            required
          />
        </div>

        <div class="auth-form__field">
          <label for="user_name">{gettext("Name")}</label>
          <input
            class="app-control"
            type="text"
            name="user[name]"
            id="user_name"
            value={@form[:name].value}
            required
          />
        </div>

        <div class="auth-form__field">
          <label for="user_email">{gettext("Email")}</label>
          <input
            class="app-control"
            type="email"
            name="user[email]"
            id="user_email"
            value={@form[:email].value}
            required
          />
        </div>

        <div class="auth-form__field">
          <label for="user_password">{gettext("Password")}</label>
          <div class="auth-form__password">
            <input
              class="app-control"
              type={if @show_password, do: "text", else: "password"}
              name="user[password]"
              id="user_password"
              value={@form[:password].value}
              required
            />
            <button
              type="button"
              class="btn--ghost auth-form__password-toggle"
              phx-click="toggle_password"
              aria-label={
                if @show_password, do: gettext("Hide password"), else: gettext("Show password")
              }
            >
              {if @show_password, do: gettext("Hide password"), else: gettext("Show password")}
            </button>
          </div>
        </div>

        <button type="submit" class="btn btn--primary auth-form__submit">
          {gettext("Create Account")}
        </button>
      </.form>

      <p class="auth-form__footer">
        {gettext("Already have an account?")}
        <.link navigate={~p"/signin"}>{gettext("Sign In Instead")}</.link>
      </p>
    </Layouts.auth>
    """
  end

  @impl true
  def handle_event("toggle_password", _params, socket) do
    {:noreply, assign(socket, :show_password, !socket.assigns.show_password)}
  end

  def handle_event("sign_up", %{"user" => params}, socket) do
    case Accounts.register_user(params) do
      {:ok, %{user: user, tenant: tenant}} ->
        token = Phoenix.Token.sign(MassTranscriptorWeb.Endpoint, "user session", user.id)
        return_to = ~p"/t/#{tenant.slug}/uploads"

        {:noreply,
         redirect(socket,
           to: ~p"/session?#{%{token: token, return_to: return_to}}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          |> Enum.map(fn {_field, messages} -> List.first(messages) end)
          |> List.first()

        {:noreply,
         socket
         |> put_flash(:error, errors || gettext("Authentication failed"))
         |> assign(:form, to_form(params, as: :user))}
    end
  end
end
