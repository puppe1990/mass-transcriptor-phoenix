defmodule MassTranscriptorWeb.UIComponents do
  @moduledoc false

  use Phoenix.Component
  use Gettext, backend: MassTranscriptorWeb.Gettext
  use MassTranscriptorWeb, :verified_routes

  alias MassTranscriptor.Jobs.Grouping

  attr :class, :string, default: "theme-toggle btn--ghost"
  attr :rest, :global

  def theme_toggle(assigns) do
    ~H"""
    <button
      type="button"
      id="theme-toggle"
      class={@class}
      phx-hook="Theme"
      data-theme-light-label={gettext("Light mode")}
      data-theme-dark-label={gettext("Dark mode")}
      data-theme-switch-to-dark={gettext("Switch to dark mode")}
      data-theme-switch-to-light={gettext("Switch to light mode")}
      aria-label={gettext("Switch to light mode")}
      {@rest}
    >
      <span data-theme-icon="dark" aria-hidden="true">
        <.moon_icon />
      </span>
      <span data-theme-icon="light" hidden aria-hidden="true">
        <.sun_icon />
      </span>
      <span data-theme-label>{gettext("Light mode")}</span>
    </button>
    """
  end

  attr :name, :atom, required: true

  def nav_icon(%{name: :uploads} = assigns) do
    ~H"""
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="17 8 12 3 7 8" />
      <line x1="12" y1="3" x2="12" y2="15" />
    </svg>
    """
  end

  def nav_icon(%{name: :jobs} = assigns) do
    ~H"""
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <line x1="8" y1="6" x2="21" y2="6" />
      <line x1="8" y1="12" x2="21" y2="12" />
      <line x1="8" y1="18" x2="21" y2="18" />
      <line x1="3" y1="6" x2="3.01" y2="6" />
      <line x1="3" y1="12" x2="3.01" y2="12" />
      <line x1="3" y1="18" x2="3.01" y2="18" />
    </svg>
    """
  end

  def nav_icon(%{name: :settings} = assigns) do
    ~H"""
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
    """
  end

  defp sun_icon(assigns) do
    ~H"""
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
    </svg>
    """
  end

  attr :status, :string, required: true

  def job_status_badge(assigns) do
    ~H"""
    <span class={["status", "status-#{@status}"]}>{status_label(@status)}</span>
    """
  end

  attr :rows, :list, required: true
  attr :tenant_slug, :string, required: true

  def jobs_table(assigns) do
    ~H"""
    <%= if @rows == [] do %>
      <div class="jobs-empty" id="jobs-empty">
        <div class="jobs-empty__icon" aria-hidden="true">
          <svg
            width="28"
            height="28"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.75"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <line x1="8" y1="6" x2="21" y2="6" />
            <line x1="8" y1="12" x2="21" y2="12" />
            <line x1="8" y1="18" x2="21" y2="18" />
            <line x1="3" y1="6" x2="3.01" y2="6" />
            <line x1="3" y1="12" x2="3.01" y2="12" />
            <line x1="3" y1="18" x2="3.01" y2="18" />
          </svg>
        </div>
        <p class="jobs-empty__title">{gettext("No jobs yet")}</p>
        <p class="jobs-empty__text">
          {gettext("Upload an audio file to start your first transcription.")}
        </p>
        <.link navigate={~p"/t/#{@tenant_slug}/uploads"}>{gettext("New upload")}</.link>
      </div>
    <% else %>
      <div class="jobs-table-wrap">
        <table class="jobs-table" id="jobs-table">
          <thead>
            <tr>
              <th>{gettext("File")}</th>
              <th>{gettext("Provider")}</th>
              <th>{gettext("Status")}</th>
              <th>{gettext("Created")}</th>
            </tr>
          </thead>
          <tbody>
            <%= for row <- @rows do %>
              <%= if row.kind == :batch do %>
                <tr id={"job-batch-#{row.batch_id}"}>
                  <td>
                    <.link
                      class="jobs-table__file-link"
                      navigate={~p"/t/#{@tenant_slug}/batches/#{row.batch_id}"}
                    >
                      {gettext("%{count} audios", count: length(row.jobs))}
                    </.link>
                    <p class="jobs-table__batch-files">
                      {Enum.map_join(row.jobs, " · ", & &1.original_filename)}
                    </p>
                  </td>
                  <td>
                    <span class="jobs-table__provider">{hd(row.jobs).provider_key}</span>
                  </td>
                  <td>
                    <.job_status_badge status={Grouping.summarize_batch_status(row.jobs)} />
                    <p :if={batch_error_message(row.jobs)} class="jobs-table__error">
                      {batch_error_message(row.jobs)}
                    </p>
                  </td>
                  <td class="jobs-table__date">{format_datetime(row.created_at)}</td>
                </tr>
              <% else %>
                <tr id={"job-row-#{row.job.id}"}>
                  <td>
                    <.link
                      class="jobs-table__file-link"
                      navigate={~p"/t/#{@tenant_slug}/jobs/#{row.job.id}"}
                    >
                      {row.job.original_filename}
                    </.link>
                  </td>
                  <td>
                    <span class="jobs-table__provider">{row.job.provider_key}</span>
                  </td>
                  <td>
                    <.job_status_badge status={row.job.status} />
                    <p :if={row.job.error_message} class="jobs-table__error">
                      {row.job.error_message}
                    </p>
                  </td>
                  <td class="jobs-table__date">{format_datetime(row.job.created_at)}</td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end

  defp batch_error_message(jobs) do
    jobs
    |> Enum.find_value(& &1.error_message)
  end

  defp status_label("queued"), do: gettext("Queued")
  defp status_label("processing"), do: gettext("Processing")
  defp status_label("completed"), do: gettext("Completed")
  defp status_label("failed"), do: gettext("Failed")
  defp status_label(_), do: gettext("Unknown")

  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y, %H:%M")
  end

  attr :text, :string, default: nil

  def transcript_preview(assigns) do
    ~H"""
    <%= if is_nil(@text) or @text == "" do %>
      <p class="transcript-preview__empty" id="transcript-empty">{gettext("No transcript yet.")}</p>
    <% else %>
      <section class="transcript-preview" id="transcript-preview">
        <div class="transcript-preview__header">
          <h2>{gettext("Transcript")}</h2>
          <button
            type="button"
            id="transcript-copy"
            class="transcript-preview__copy"
            phx-hook=".CopyText"
            data-copy-text={@text}
            data-copied-label={gettext("Copied")}
            data-copy-label={gettext("Copy Text")}
          >
            {gettext("Copy Text")}
          </button>
        </div>
        <p id="transcript-copy-status" class="transcript-preview__status" hidden role="status" />
        <pre id="transcript-text">{@text}</pre>
      </section>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyText">
        export default {
          mounted() {
            this.el.addEventListener("click", async () => {
              const text = this.el.dataset.copyText || "";
              const status = document.getElementById("transcript-copy-status");
              const copiedLabel = this.el.dataset.copiedLabel || "Copied";
              const copyLabel = this.el.dataset.copyLabel || "Copy Text";

              if (!navigator.clipboard) {
                if (status) {
                  status.hidden = false;
                  status.textContent = "Could not copy text.";
                }
                return;
              }

              try {
                await navigator.clipboard.writeText(text);
                this.el.textContent = copiedLabel;
                if (status) status.hidden = true;
                window.setTimeout(() => {
                  this.el.textContent = copyLabel;
                }, 2000);
              } catch {
                if (status) {
                  status.hidden = false;
                  status.textContent = "Could not copy text.";
                }
              }
            });
          }
        }
      </script>
    <% end %>
    """
  end

  attr :job, :map, required: true
  attr :tenant_slug, :string, required: true
  attr :retrying?, :boolean, default: false

  def job_detail_panel(assigns) do
    ~H"""
    <div class="job-meta" id={"job-meta-#{@job.id}"}>
      <div class="job-meta__item">
        <p class="job-meta__label">{gettext("Provider")}</p>
        <p class="job-meta__value">{@job.provider_key}</p>
      </div>
      <div class="job-meta__item">
        <p class="job-meta__label">{gettext("Status")}</p>
        <p class="job-meta__value">
          <.job_status_badge status={@job.status} />
        </p>
      </div>
      <div :if={@job.markdown_path} class="job-meta__item">
        <p class="job-meta__label">{gettext("Output")}</p>
        <p class="job-meta__value job-meta__value--muted">{@job.markdown_path}</p>
      </div>
    </div>

    <div class="job-actions" id={"job-actions-#{@job.id}"}>
      <%= if @job.status == "failed" do %>
        <button
          type="button"
          id={"retry-job-#{@job.id}"}
          phx-click="retry_job"
          phx-value-job-id={@job.id}
          disabled={@retrying?}
        >
          <%= if @retrying? do %>
            {gettext("Retrying...")}
          <% else %>
            {gettext("Retry job")}
          <% end %>
        </button>
      <% end %>
      <%= if @job.markdown_path do %>
        <.link
          id={"download-job-#{@job.id}"}
          href={~p"/t/#{@tenant_slug}/jobs/#{@job.id}/download"}
        >
          {gettext("Download Markdown")}
        </.link>
      <% end %>
    </div>

    <p :if={@job.error_message} class="page-alert" id={"job-error-#{@job.id}"} role="alert">
      {@job.error_message}
    </p>

    <.transcript_preview text={@job.transcript_text} />
    """
  end

  defp moon_icon(assigns) do
    ~H"""
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
    </svg>
    """
  end
end
