defmodule MassTranscriptorWeb.JobLive do
  use MassTranscriptorWeb, :live_view

  alias MassTranscriptor.Jobs

  @poll_interval_ms 2_000

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job_id = String.to_integer(id)
    tenant_id = socket.assigns.current_tenant.id

    case Jobs.get_job_detail_for_tenant(tenant_id, job_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Job not found."))
         |> redirect(to: ~p"/t/#{socket.assigns.tenant_slug}/jobs")}

      job ->
        socket =
          socket
          |> assign(:page_title, job.original_filename)
          |> assign(:active_tab, :jobs)
          |> assign(:job, job)
          |> assign(:retrying?, false)

        if connected?(socket) and job.status in ["queued", "processing"],
          do: send(self(), :poll)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("retry_job", %{"job-id" => job_id}, socket) do
    job_id = String.to_integer(job_id)
    tenant_id = socket.assigns.current_tenant.id

    socket = assign(socket, :retrying?, true)

    socket =
      case Jobs.get_job_detail_for_tenant(tenant_id, job_id) do
        nil ->
          put_flash(socket, :error, gettext("Job not found."))

        %{status: "failed"} ->
          job = Jobs.fetch_job!(job_id)

          case Jobs.retry_job(job) do
            {:ok, _job} ->
              reload_job(socket)

            {:error, _} ->
              put_flash(socket, :error, gettext("Could not retry this job."))
          end

        _ ->
          put_flash(socket, :error, gettext("Only failed jobs can be retried."))
      end

    {:noreply, assign(socket, :retrying?, false)}
  end

  @impl true
  def handle_info(:poll, socket) do
    {:noreply, socket |> reload_job() |> schedule_poll()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} tenant_slug={@tenant_slug} active_tab={@active_tab} locale={@locale}>
      <section class="page">
        <header class="page__header">
          <.link class="page__back" navigate={~p"/t/#{@tenant_slug}/jobs"}>
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <polyline points="15 18 9 12 15 6" />
            </svg>
            {gettext("Back to jobs")}
          </.link>
          <h1 class="page__title">{@job.original_filename}</h1>
        </header>

        <div class="page__body">
          <.job_detail_panel job={@job} tenant_slug={@tenant_slug} retrying?={@retrying?} />
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp reload_job(socket) do
    job =
      Jobs.get_job_detail_for_tenant(
        socket.assigns.current_tenant.id,
        socket.assigns.job.id
      )

    assign(socket, :job, job)
  end

  defp schedule_poll(socket) do
    if socket.assigns.job.status in ["queued", "processing"] do
      Process.send_after(self(), :poll, @poll_interval_ms)
    end

    socket
  end
end
