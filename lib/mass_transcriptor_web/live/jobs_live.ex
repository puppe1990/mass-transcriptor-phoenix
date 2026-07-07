defmodule MassTranscriptorWeb.JobsLive do
  use MassTranscriptorWeb, :live_view

  alias MassTranscriptor.Jobs
  alias MassTranscriptor.Jobs.{Grouping, Pagination}

  @poll_interval_ms 2_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :poll)

    {:ok,
     socket
     |> assign(:page_title, gettext("Jobs"))
     |> assign(:active_tab, :jobs)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load_jobs(socket, params)}
  end

  @impl true
  def handle_info(:poll, socket) do
    params = %{"page" => Integer.to_string(socket.assigns.pagination.page)}

    {:noreply, socket |> load_jobs(params) |> schedule_poll()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} tenant_slug={@tenant_slug} active_tab={@active_tab} locale={@locale}>
      <section class="page">
        <header class="page__header">
          <p class="page__eyebrow">{@tenant_slug}</p>
          <h1 class="page__title">{gettext("Jobs")}</h1>
          <div class="page__actions">
            <.link navigate={~p"/t/#{@tenant_slug}/uploads"}>{gettext("New upload")}</.link>
          </div>
        </header>
        <div class="page__body">
          <.jobs_table rows={@job_rows} tenant_slug={@tenant_slug} />
          <.jobs_pagination
            :if={@pagination.total_pages > 1}
            pagination={@pagination}
            tenant_slug={@tenant_slug}
          />
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp load_jobs(socket, params) do
    jobs = Jobs.list_job_summaries_for_tenant(socket.assigns.current_tenant.id)
    pagination = jobs |> Grouping.build_job_list_rows() |> Pagination.paginate(params["page"])

    socket
    |> assign(:jobs, jobs)
    |> assign(:pagination, pagination)
    |> assign(:job_rows, pagination.rows)
  end

  defp schedule_poll(socket) do
    if active_jobs?(socket.assigns.jobs) do
      Process.send_after(self(), :poll, @poll_interval_ms)
    end

    socket
  end

  defp active_jobs?(jobs) do
    Enum.any?(jobs, &(&1.status in ["queued", "processing"]))
  end
end
