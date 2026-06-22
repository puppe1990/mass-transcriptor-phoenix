defmodule MassTranscriptorWeb.Router do
  use MassTranscriptorWeb, :router

  import MassTranscriptorWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MassTranscriptorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MassTranscriptorWeb do
    pipe_through :browser

    get "/", RedirectController, :home
    get "/session", UserSessionController, :create
    delete "/signout", UserSessionController, :delete

    live_session :public,
      on_mount: [{MassTranscriptorWeb.UserAuth, :mount_current_user}] do
      live "/signin", AuthLive.SignIn, :sign_in
      live "/signup", AuthLive.SignUp, :sign_up
    end
  end

  scope "/t/:tenant_slug", MassTranscriptorWeb do
    pipe_through :browser

    get "/jobs/:id/download", JobDownloadController, :show
    get "/batches/:id/download", BatchDownloadController, :show

    live_session :authenticated,
      on_mount: [
        {MassTranscriptorWeb.UserAuth, :ensure_authenticated},
        {MassTranscriptorWeb.UserAuth, :ensure_tenant_member},
        {MassTranscriptorWeb.LocaleHook, :default}
      ] do
      live "/uploads", UploadLive, :index
      live "/jobs", JobsLive, :index
      live "/jobs/:id", JobLive, :show
      live "/batches/:id", BatchLive, :show
      live "/settings", SettingsLive, :index
    end
  end

  if Application.compile_env(:mass_transcriptor, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MassTranscriptorWeb.Telemetry
    end
  end
end
