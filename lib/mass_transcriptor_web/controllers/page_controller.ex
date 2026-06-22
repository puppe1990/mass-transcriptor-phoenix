defmodule MassTranscriptorWeb.PageController do
  use MassTranscriptorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
