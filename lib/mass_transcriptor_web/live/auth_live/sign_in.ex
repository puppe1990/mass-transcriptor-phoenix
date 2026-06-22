defmodule MassTranscriptorWeb.AuthLive.SignIn do
  use MassTranscriptorWeb, :live_view

  alias MassTranscriptor.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Sign In"))
     |> assign(:form, to_form(%{"email" => "", "password" => ""}, as: :user))
     |> assign(:show_password, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth
      flash={@flash}
      eyebrow={gettext("Welcome back")}
      title={gettext("Sign In")}
      subtitle={gettext("Continue into your workspace and keep your transcripts flowing.")}
    >
      <.form for={@form} id="sign-in-form" phx-submit="sign_in" class="auth-form">
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
          {gettext("Sign In")}
        </button>
      </.form>

      <p class="auth-form__footer">
        {gettext("Need a workspace?")}
        <.link navigate={~p"/signup"}>{gettext("Create Workspace")}</.link>
      </p>
    </Layouts.auth>
    """
  end

  @impl true
  def handle_event("toggle_password", _params, socket) do
    {:noreply, assign(socket, :show_password, !socket.assigns.show_password)}
  end

  def handle_event("sign_in", %{"user" => %{"email" => email, "password" => password}}, socket) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        memberships = Accounts.list_memberships_for_user(user.id)
        tenant_slug = memberships |> List.first() |> then(&(&1 && &1.tenant.slug))

        return_to =
          if tenant_slug do
            ~p"/t/#{tenant_slug}/uploads"
          else
            ~p"/signin"
          end

        token = Phoenix.Token.sign(MassTranscriptorWeb.Endpoint, "user session", user.id)

        {:noreply,
         redirect(socket,
           to: ~p"/session?#{%{token: token, return_to: return_to}}"
         )}

      {:error, :invalid_credentials} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Authentication failed"))
         |> assign(:form, to_form(%{"email" => email, "password" => ""}, as: :user))}
    end
  end
end
