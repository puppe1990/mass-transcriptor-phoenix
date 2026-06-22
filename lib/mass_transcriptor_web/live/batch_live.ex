defmodule MassTranscriptorWeb.BatchLive do
  use MassTranscriptorWeb, :live_view

  alias MassTranscriptor.Jobs

  @poll_interval_ms 2_000

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    batch_id = String.to_integer(id)
    tenant_id = socket.assigns.current_tenant.id

    case Jobs.get_batch_for_tenant(tenant_id, batch_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Batch not found."))
         |> redirect(to: ~p"/t/#{socket.assigns.tenant_slug}/jobs")}

      batch ->
        active_job_id = hd(batch.jobs).id

        socket =
          socket
          |> assign(:page_title, gettext("Upload group"))
          |> assign(:active_tab, :jobs)
          |> assign(:batch, batch)
          |> assign(:active_job_id, active_job_id)
          |> assign(:retrying?, false)

        if connected?(socket), do: send(self(), :poll)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("select_tab", %{"job-id" => job_id}, socket) do
    {:noreply, assign(socket, :active_job_id, String.to_integer(job_id))}
  end

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
              reload_batch(socket)

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
    {:noreply, socket |> reload_batch() |> schedule_poll()}
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
          <h1 class="page__title">
            {gettext("Upload group · %{count} audios", count: length(@batch.jobs))}
          </h1>
          <p class="page__subtitle">{format_datetime(@batch.created_at)}</p>
          <div :if={Jobs.downloadable_transcripts?(@batch.jobs)} class="page__actions">
            <.link
              id="batch-download-all"
              href={~p"/t/#{@tenant_slug}/batches/#{@batch.id}/download"}
            >
              {gettext("Download all")}
            </.link>
          </div>
        </header>

        <div class="page__body">
          <div class="job-batch-tabs" role="tablist" aria-label={gettext("Batch files")}>
            <%= for job <- @batch.jobs do %>
              <button
                type="button"
                id={"batch-tab-#{job.id}"}
                role="tab"
                aria-selected={job.id == @active_job_id}
                class={[
                  "job-batch-tabs__tab",
                  job.id == @active_job_id && "job-batch-tabs__tab--active"
                ]}
                phx-click="select_tab"
                phx-value-job-id={job.id}
              >
                <span class="job-batch-tabs__label">{job.original_filename}</span>
                <.job_status_badge status={job.status} />
              </button>
            <% end %>
          </div>

          <%= if active_job = find_active_job(@batch.jobs, @active_job_id) do %>
            <div class="job-batch-panel" role="tabpanel" id={"batch-panel-#{active_job.id}"}>
              <.job_detail_panel
                job={active_job}
                tenant_slug={@tenant_slug}
                retrying?={@retrying?}
              />
            </div>
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp reload_batch(socket) do
    batch =
      Jobs.get_batch_for_tenant(
        socket.assigns.current_tenant.id,
        socket.assigns.batch.id
      )

    active_job_id =
      if Enum.any?(socket.assigns.batch.jobs, &(&1.id == socket.assigns.active_job_id)) do
        socket.assigns.active_job_id
      else
        hd(batch.jobs).id
      end

    assign(socket, batch: batch, active_job_id: active_job_id)
  end

  defp schedule_poll(socket) do
    if active_jobs?(socket.assigns.batch.jobs) do
      Process.send_after(self(), :poll, @poll_interval_ms)
    end

    socket
  end

  defp active_jobs?(jobs) do
    Enum.any?(jobs, &(&1.status in ["queued", "processing"]))
  end

  defp find_active_job(jobs, active_job_id) do
    Enum.find(jobs, &(&1.id == active_job_id)) || List.first(jobs)
  end

  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y, %H:%M")
  end
end
