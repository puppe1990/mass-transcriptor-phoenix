defmodule MassTranscriptor.DotenvTest do
  use ExUnit.Case, async: true

  alias MassTranscriptor.Dotenv

  test "load/1 reads KEY=value pairs without overriding existing vars" do
    path = Path.join(System.tmp_dir!(), "dotenv-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)

    File.write!(path, """
    # comment
    FOO=from_file
    BAR=baz
    """)

    System.put_env("FOO", "already_set")

    Dotenv.load(path)

    assert System.get_env("FOO") == "already_set"
    assert System.get_env("BAR") == "baz"

    System.delete_env("BAR")
    System.delete_env("FOO")
  end
end
