defmodule MassTranscriptorWeb.PageHTMLTest do
  use MassTranscriptorWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "renders home.html with flash messages" do
    html =
      render_to_string(MassTranscriptorWeb.PageHTML, "home", "html", %{
        flash: %{"info" => "Welcome", "error" => "Something went wrong"}
      })

    assert html =~ "Phoenix Framework"
    assert html =~ "Welcome"
    assert html =~ "Something went wrong"
    assert html =~ "flash-toast--info"
    assert html =~ "flash-toast--error"
  end
end
