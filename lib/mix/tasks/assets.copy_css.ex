defmodule Mix.Tasks.Assets.CopyCss do
  @shortdoc "Copies tracked CSS into priv/static before digest"
  @moduledoc false

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    dest_dir = Path.join(["priv", "static", "assets", "css"])
    dest = Path.join(dest_dir, "app.css")
    source = Path.join(["assets", "css", "app.css"])

    File.mkdir_p!(dest_dir)
    File.cp!(source, dest)

    Mix.shell().info("Copied #{source} -> #{dest}")
  end
end
