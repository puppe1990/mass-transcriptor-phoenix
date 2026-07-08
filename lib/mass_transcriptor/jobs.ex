defmodule MassTranscriptor.Jobs do
  @moduledoc false

  import Ecto.Query, warn: false

  alias MassTranscriptor.Accounts.Tenant

  alias MassTranscriptor.Jobs.{
    JobBatch,
    TenantProviderSetting,
    TranscriptionJob,
    TranscriptionResult,
    Upload
  }

  alias MassTranscriptor.Repo
  alias MassTranscriptor.Storage
  alias MassTranscriptor.Transcription.{AssemblyAI, Markdown}
  alias MassTranscriptor.Workers.TranscribeJob
  alias Oban.Job, as: ObanJob

  def create_uploads_and_jobs(%Tenant{} = tenant, files) when is_list(files) do
    Repo.checkout(
      fn ->
        batch = maybe_create_batch!(tenant, files)

        Enum.map(files, &create_upload_and_job!(tenant, batch, &1))
      end,
      timeout: :timer.seconds(60)
    )
  end

  defp maybe_create_batch!(_tenant, [_single]), do: nil

  defp maybe_create_batch!(tenant, _files) do
    {:ok, batch} = Repo.insert(%JobBatch{tenant_id: tenant.id})
    batch
  end

  defp create_upload_and_job!(tenant, batch, file) do
    {:ok, upload} =
      %Upload{}
      |> Ecto.Changeset.change(%{
        tenant_id: tenant.id,
        original_filename: file.filename,
        mime_type: file.mime_type,
        size_bytes: file.size,
        audio_path: "pending"
      })
      |> Repo.insert()

    audio_path = Storage.write_audio(tenant.slug, upload.id, file.filename, file.content)

    {:ok, upload} =
      upload
      |> Upload.audio_changeset(%{audio_path: audio_path})
      |> Repo.update()

    {:ok, job} =
      %TranscriptionJob{}
      |> TranscriptionJob.changeset(%{
        tenant_id: tenant.id,
        upload_id: upload.id,
        batch_id: batch && batch.id,
        provider_key: tenant.default_provider,
        status: "queued"
      })
      |> Repo.insert()

    {:ok, _oban_job} = enqueue_transcription(job)

    job
  end

  defp enqueue_transcription(job) do
    %{job_id: job.id}
    |> TranscribeJob.new()
    |> Oban.insert()
  end

  def process_transcription_job(job_id) do
    job = fetch_job!(job_id)

    if job.status == "completed" do
      :ok
    else
      with {:ok, job} <- mark_job_processing(job),
           {:ok, result} <- transcribe(job),
           {:ok, _job} <- mark_job_completed(job, result) do
        :ok
      else
        {:error, message} when is_binary(message) ->
          mark_job_failed(job, message)

        {:error, reason} ->
          mark_job_failed(job, inspect(reason))
      end
    end
  end

  def list_job_summaries_for_tenant(tenant_id) do
    TranscriptionJob
    |> where([j], j.tenant_id == ^tenant_id)
    |> join(:inner, [j], u in assoc(j, :upload))
    |> order_by([j], desc: j.inserted_at)
    |> select([j, u], %{
      id: j.id,
      status: j.status,
      provider_key: j.provider_key,
      batch_id: j.batch_id,
      upload_id: j.upload_id,
      original_filename: u.original_filename,
      error_message: j.error_message,
      created_at: j.inserted_at
    })
    |> Repo.all()
  end

  def fetch_job!(job_id) do
    TranscriptionJob
    |> where([j], j.id == ^job_id)
    |> preload([:upload, :tenant])
    |> Repo.one!()
  end

  def get_batch_for_tenant(tenant_id, batch_id) do
    case Repo.get_by(JobBatch, id: batch_id, tenant_id: tenant_id) do
      nil ->
        nil

      batch ->
        jobs =
          TranscriptionJob
          |> where([j], j.batch_id == ^batch.id and j.tenant_id == ^tenant_id)
          |> order_by([j], asc: j.id)
          |> preload(:upload)
          |> Repo.all()

        %{
          id: batch.id,
          created_at: batch.inserted_at,
          jobs: Enum.map(jobs, &build_job_detail/1)
        }
    end
  end

  def get_job_detail_for_tenant(tenant_id, job_id) do
    case Repo.get_by(TranscriptionJob, id: job_id, tenant_id: tenant_id) do
      nil -> nil
      job -> build_job_detail(Repo.preload(job, :upload))
    end
  end

  def get_job_for_download(tenant_id, job_id) do
    TranscriptionJob
    |> where([j], j.id == ^job_id and j.tenant_id == ^tenant_id)
    |> preload(:upload)
    |> Repo.one()
  end

  def build_job_detail(%TranscriptionJob{} = job) do
    result = Repo.get_by(TranscriptionResult, job_id: job.id)

    %{
      id: job.id,
      status: job.status,
      provider_key: job.provider_key,
      batch_id: job.batch_id,
      upload_id: job.upload_id,
      original_filename: job.upload.original_filename,
      error_message: job.error_message,
      markdown_path: result && result.markdown_path,
      transcript_text: result && result.transcript_text,
      inserted_at: job.inserted_at,
      started_at: job.started_at,
      retryable?: retryable?(job),
      stuck?: stuck?(job)
    }
  end

  def retryable?(%{status: "failed"}), do: true
  def retryable?(%TranscriptionJob{status: "failed"}), do: true
  def retryable?(job), do: stuck?(job)

  def stuck?(%{status: status, inserted_at: inserted_at, started_at: started_at}) do
    stuck_by_status?(status, inserted_at, started_at)
  end

  def stuck?(%TranscriptionJob{} = job) do
    stuck_by_status?(job.status, job.inserted_at, job.started_at)
  end

  def retry_job(%TranscriptionJob{status: "failed"} = job) do
    requeue_job(job, reset_timestamps: true)
  end

  def retry_job(%TranscriptionJob{} = job) do
    if stuck?(job) do
      requeue_job(job, reset_timestamps: job.status == "processing")
    else
      {:error, :not_retryable}
    end
  end

  defp requeue_job(job, opts) do
    cancel_oban_jobs_for(job.id)

    changes =
      if opts[:reset_timestamps] do
        %{status: "queued", error_message: nil, started_at: nil, completed_at: nil}
      else
        %{status: "queued", error_message: nil}
      end

    with {:ok, job} <-
           job
           |> TranscriptionJob.changeset(changes)
           |> Repo.update(),
         {:ok, _oban_job} <- enqueue_transcription(job) do
      {:ok, job}
    end
  end

  defp stuck_by_status?("queued", inserted_at, _started_at) do
    minutes_since(inserted_at) >= stuck_after_minutes()
  end

  defp stuck_by_status?("processing", _inserted_at, started_at) when not is_nil(started_at) do
    minutes_since(started_at) >= stuck_after_minutes()
  end

  defp stuck_by_status?(_, _, _), do: false

  defp stuck_after_minutes do
    Application.get_env(:mass_transcriptor, :job_stuck_after_minutes, 5)
  end

  defp minutes_since(%DateTime{} = datetime) do
    DateTime.diff(DateTime.utc_now(), datetime, :minute)
  end

  defp cancel_oban_jobs_for(job_id) do
    worker = "MassTranscriptor.Workers.TranscribeJob"

    ObanJob
    |> where([j], j.worker == ^worker)
    |> where([j], j.state in ["executing", "available", "retryable", "scheduled"])
    |> Repo.all()
    |> Enum.filter(fn %ObanJob{args: args} ->
      oban_job_id(args) == job_id
    end)
    |> Enum.each(&Oban.cancel_job/1)

    :ok
  end

  defp oban_job_id(%{"job_id" => job_id}) when is_integer(job_id), do: job_id
  defp oban_job_id(%{"job_id" => job_id}) when is_binary(job_id), do: String.to_integer(job_id)
  defp oban_job_id(_), do: nil

  def downloadable_transcripts?(jobs) when is_list(jobs) do
    Enum.any?(jobs, &downloadable_transcript?/1)
  end

  def downloadable_transcript?(%{markdown_path: path}) when is_binary(path) do
    File.exists?(path)
  end

  def downloadable_transcript?(_), do: false

  def build_batch_transcripts_zip(jobs) when is_list(jobs) do
    entries =
      jobs
      |> Enum.filter(&downloadable_transcript?/1)
      |> Enum.map(fn job ->
        filename =
          job.original_filename
          |> Path.basename()
          |> Path.rootname()
          |> Kernel.<>(".md")
          |> String.to_charlist()

        {filename, File.read!(job.markdown_path)}
      end)

    case entries do
      [] ->
        {:error, :empty}

      files ->
        case :zip.create(~c"transcripts.zip", files, [:memory]) do
          {:ok, {_name, binary}} -> {:ok, binary}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def mark_job_processing(%TranscriptionJob{status: "completed"} = job), do: {:ok, job}

  def mark_job_processing(%TranscriptionJob{} = job) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    job
    |> TranscriptionJob.changeset(%{status: "processing", started_at: now})
    |> Repo.update()
  end

  def mark_job_completed(job, %{text: text, metadata: metadata}) do
    markdown =
      Markdown.render(text, job.upload.original_filename, job.provider_key)

    markdown_path = Storage.write_markdown(job.tenant.slug, job.upload.id, markdown)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with {:ok, _result} <-
           %TranscriptionResult{}
           |> TranscriptionResult.changeset(%{
             job_id: job.id,
             tenant_id: job.tenant_id,
             markdown_path: markdown_path,
             transcript_text: text,
             provider_metadata_json: Jason.encode!(metadata)
           })
           |> Repo.insert() do
      job
      |> TranscriptionJob.changeset(%{
        status: "completed",
        completed_at: now,
        error_message: nil
      })
      |> Repo.update()
    end
  end

  def mark_job_failed(%TranscriptionJob{} = job, message) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    trimmed = String.slice(message, 0, 500)

    job
    |> TranscriptionJob.changeset(%{status: "failed", error_message: trimmed, completed_at: now})
    |> Repo.update()
    |> case do
      {:ok, _job} -> {:error, trimmed}
      {:error, changeset} -> {:error, inspect(changeset.errors)}
    end
  end

  defp transcribe(%TranscriptionJob{provider_key: "assemblyai"} = job) do
    api_key = assemblyai_api_key()

    if is_nil(api_key) or api_key == "" do
      {:error, "AssemblyAI requires ASSEMBLYAI_API_KEY to be configured on the server"}
    else
      language = resolve_language(job.tenant_id)

      provider_module().transcribe(job.upload.audio_path,
        api_key: api_key,
        language: language
      )
    end
  end

  defp transcribe(%TranscriptionJob{provider_key: provider_key}) do
    {:error, "Provider #{provider_key} is not available in this version"}
  end

  defp provider_module do
    Application.get_env(
      :mass_transcriptor,
      :transcription_provider,
      AssemblyAI
    )
  end

  defp assemblyai_api_key do
    Application.get_env(:mass_transcriptor, :assemblyai_api_key)
  end

  defp resolve_language(tenant_id) do
    case Repo.get_by(TenantProviderSetting, tenant_id: tenant_id, provider_key: "whisper") do
      nil ->
        nil

      %{config_json: json} ->
        with {:ok, %{"language" => language}} <- Jason.decode(json || "{}"),
             true <- language in ["pt", "en", "es"] do
          language
        else
          _ -> nil
        end
    end
  end
end
