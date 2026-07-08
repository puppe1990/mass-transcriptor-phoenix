defmodule MassTranscriptor.Storage do
  @moduledoc false

  def root do
    Application.get_env(:mass_transcriptor, :storage_root)
  end

  def build_upload_dir(tenant_slug, upload_id) do
    Path.join([root(), tenant_slug, "uploads", to_string(upload_id)])
  end

  def build_source_dir(tenant_slug, upload_id) do
    Path.join([build_upload_dir(tenant_slug, upload_id), "source"])
  end

  def build_source_path(tenant_slug, upload_id, filename) do
    Path.join([build_source_dir(tenant_slug, upload_id), filename])
  end

  def build_audio_path(tenant_slug, upload_id, filename) do
    Path.join([build_upload_dir(tenant_slug, upload_id), "audio", filename])
  end

  def build_markdown_path(tenant_slug, upload_id) do
    Path.join([build_upload_dir(tenant_slug, upload_id), "transcript", "transcript.md"])
  end

  def write_audio(tenant_slug, upload_id, filename, content) when is_binary(content) do
    path = build_audio_path(tenant_slug, upload_id, filename)
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, content)
    path
  end

  def write_source_from_path(tenant_slug, upload_id, filename, source_path)
      when is_binary(source_path) do
    dest = build_source_path(tenant_slug, upload_id, filename)
    dest |> Path.dirname() |> File.mkdir_p!()
    File.cp!(source_path, dest)
    dest
  end

  def write_audio_from_path(tenant_slug, upload_id, filename, source_path)
      when is_binary(source_path) do
    path = build_audio_path(tenant_slug, upload_id, filename)
    path |> Path.dirname() |> File.mkdir_p!()
    File.cp!(source_path, path)
    path
  end

  def cleanup_upload_media(tenant_slug, upload_id) do
    upload_dir = build_upload_dir(tenant_slug, upload_id)

    for subdir <- ["source", "audio"] do
      File.rm_rf(Path.join(upload_dir, subdir))
    end

    :ok
  end

  def write_markdown(tenant_slug, upload_id, content) when is_binary(content) do
    path = build_markdown_path(tenant_slug, upload_id)
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, content)
    path
  end
end