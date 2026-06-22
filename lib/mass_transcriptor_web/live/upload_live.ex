defmodule MassTranscriptorWeb.UploadLive do
  use MassTranscriptorWeb, :live_view

  alias MassTranscriptor.Jobs
  alias MassTranscriptorWeb.UploadFormats

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Upload Audio"))
     |> assign(:active_tab, :uploads)
     |> assign(:uploaded_jobs, [])
     |> assign(:upload_error, nil)
     |> allow_upload(:audio,
       accept: UploadFormats.extensions(),
       max_entries: 20,
       max_file_size: 100_000_000,
       auto_upload: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} tenant_slug={@tenant_slug} active_tab={@active_tab} locale={@locale}>
      <header class="page__header">
        <p class="page__eyebrow">{gettext("Uploads")}</p>
        <h1 class="page__title">{gettext("Upload Audio")}</h1>
        <p class="page__subtitle">
          {gettext("Tenant: %{tenant_slug}", tenant_slug: @tenant_slug)}
        </p>
      </header>

      <div
        :if={@uploaded_jobs != []}
        id="upload-success"
        class="upload-success"
        phx-mounted={scroll_into_view("#upload-success")}
      >
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
          <polyline points="20 6 9 17 4 12" />
        </svg>
        <span>
          {queued_panel_message(@uploaded_jobs)}
          <%= if batch_upload?(@uploaded_jobs) do %>
            <.link navigate={~p"/t/#{@tenant_slug}/batches/#{hd(@uploaded_jobs).batch_id}"}>
              {gettext("Open upload group")}
            </.link>
          <% else %>
            <%= for {job, index} <- Enum.with_index(@uploaded_jobs) do %>
              {if index > 0, do: ", "}
              <.link navigate={~p"/t/#{@tenant_slug}/jobs/#{job.id}"}>
                {gettext("Open job")} #{job.id}
              </.link>
            <% end %>
          <% end %>
        </span>
      </div>

      <form id="upload-form" phx-submit="upload" phx-change="validate">
        <div
          class={[
            "upload-dropzone",
            @uploads.audio.entries != [] && "upload-dropzone--active",
            display_upload_error(assigns) && "upload-dropzone--error"
          ]}
          phx-drop-target={@uploads.audio.ref}
        >
          <p>{gettext("Drag and drop audio files here, or use the file picker below.")}</p>
          <p class="upload-dropzone__hint">{UploadFormats.hint()}</p>
          <label class="btn btn--primary">
            {gettext("Audio file")}
            <.live_file_input upload={@uploads.audio} class="sr-only" />
          </label>
        </div>

        <div
          :if={display_upload_error(assigns)}
          id="upload-error"
          class="upload-error upload-error--banner"
          role="alert"
          phx-mounted={scroll_into_view("#upload-error")}
        >
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
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12.01" y2="16" />
          </svg>
          <div>
            <strong>{gettext("Cannot upload this file")}</strong>
            <p>{display_upload_error(assigns)}</p>
          </div>
        </div>

        <p
          :if={show_empty_hint?(assigns)}
          id="upload-empty-hint"
          class="upload-empty-hint"
        >
          {gettext("Select at least one audio file to start transcription.")}
        </p>

        <ul :if={@uploads.audio.entries != []} class="upload-file-list">
          <li :for={entry <- @uploads.audio.entries} class="upload-file-list__item">
            <span>{entry.client_name}</span>
            <p :if={entry_error(entry)} class="upload-file-list__error">{entry_error(entry)}</p>
            <button type="button" phx-click="cancel" phx-value-ref={entry.ref} class="btn--ghost">
              {gettext("Remove %{name}", name: entry.client_name)}
            </button>
          </li>
        </ul>

        <div id="upload-submitting" class="upload-submitting" aria-live="polite">
          <span class="upload-submitting__spinner" aria-hidden="true"></span>
          <span>{gettext("Uploading and queuing transcription...")}</span>
        </div>

        <div class="upload-actions">
          <button
            :if={@uploads.audio.entries != []}
            type="button"
            class="btn--ghost"
            phx-click="clear_all"
          >
            {gettext("Clean all")}
          </button>
          <button
            id="upload-submit"
            type="submit"
            class="btn btn--primary"
            disabled={not ready_to_submit?(assigns)}
            aria-describedby={unless ready_to_submit?(assigns), do: "upload-empty-hint"}
            phx-disable-with={gettext("Uploading...")}
          >
            {gettext("Start Transcription")}
          </button>
        </div>
      </form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    message = upload_error_message(socket)

    socket =
      socket
      |> assign(:upload_error, message)
      |> maybe_flash_upload_error(message)

    {:noreply, socket}
  end

  def handle_event("cancel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :audio, ref)}
  end

  def handle_event("clear_all", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.audio.entries, socket, fn entry, acc ->
        cancel_upload(acc, :audio, entry.ref)
      end)

    {:noreply, assign(socket, :upload_error, nil)}
  end

  def handle_event("upload", _params, socket) do
    tenant = socket.assigns.current_tenant

    socket = assign(socket, :uploaded_jobs, [])

    files =
      consume_uploaded_entries(socket, :audio, fn %{path: path}, entry ->
        {:ok,
         %{
           filename: entry.client_name,
           mime_type: entry.client_type || "application/octet-stream",
           size: entry.client_size,
           content: File.read!(path)
         }}
      end)

    case files do
      [] ->
        message = upload_error_message(socket) || gettext("Upload failed")

        {:noreply,
         socket
         |> assign(:upload_error, message)
         |> put_flash(:error, message)}

      files ->
        jobs = Jobs.create_uploads_and_jobs(tenant, files)

        {:noreply,
         socket
         |> assign(:uploaded_jobs, jobs)
         |> assign(:upload_error, nil)
         |> put_flash(:info, queued_message(length(jobs)))}
    end
  end

  defp queued_message(1), do: gettext("Job queued.")
  defp queued_message(count), do: gettext("%{count} jobs queued.", count: count)

  defp queued_panel_message([_single]), do: gettext("Job queued.") <> " "

  defp queued_panel_message(jobs),
    do: gettext("%{count} jobs queued.", count: length(jobs)) <> " "

  defp batch_upload?([%{batch_id: batch_id} | _]) when not is_nil(batch_id), do: true
  defp batch_upload?(_), do: false

  defp scroll_into_view(selector) do
    JS.dispatch("mass-transcriptor:scroll-into-view", to: selector)
  end

  defp display_upload_error(assigns) do
    assigns.upload_error || live_upload_error(assigns.uploads.audio)
  end

  defp live_upload_error(config) do
    cond do
      invalid_entry = Enum.find(config.entries, &(not &1.valid?)) ->
        file_rejected_message(invalid_entry.client_name)

      config.errors != [] ->
        config.errors
        |> Enum.map(&config_error_to_string(&1, config))
        |> Enum.uniq()
        |> Enum.join(" ")

      true ->
        nil
    end
  end

  defp upload_error_message(socket) do
    live_upload_error(socket.assigns.uploads.audio)
  end

  defp config_error_to_string({ref, reason}, config) do
    entry = Enum.find(config.entries, &(&1.ref == ref))
    upload_error_to_string({reason, entry})
  end

  defp config_error_to_string(error, _config), do: upload_error_to_string(error)

  defp upload_error_to_string({:not_accepted, %{client_name: name}}),
    do: file_rejected_message(name)

  defp upload_error_to_string({:not_accepted, _entry}), do: UploadFormats.error_message()
  defp upload_error_to_string({:too_large, entry}), do: too_large_message(entry)
  defp upload_error_to_string({:too_many_files, _entry}), do: gettext("Too many files selected.")

  defp upload_error_to_string({msg, _entry}) when is_binary(msg), do: msg

  defp upload_error_to_string(_),
    do: gettext("Upload failed. Check the file type and try again.")

  defp too_large_message(entry) do
    gettext("%{name} is too large.", name: entry.client_name)
  end

  defp entry_error(%{valid?: false} = entry) do
    file_rejected_message(entry.client_name)
  end

  defp entry_error(_), do: nil

  defp file_rejected_message(name) do
    gettext(
      "%{name} is not supported. Use OGG, MP3, WAV, M4A, or other common audio formats.",
      name: name
    )
  end

  defp show_empty_hint?(assigns) do
    assigns.uploads.audio.entries == [] and is_nil(display_upload_error(assigns))
  end

  defp ready_to_submit?(assigns) do
    assigns.uploads.audio.entries != [] and
      Enum.all?(assigns.uploads.audio.entries, & &1.valid?)
  end

  defp maybe_flash_upload_error(socket, nil), do: socket

  defp maybe_flash_upload_error(socket, message) do
    put_flash(socket, :error, message)
  end
end
