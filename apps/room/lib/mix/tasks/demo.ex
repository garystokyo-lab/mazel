defmodule Mix.Tasks.Demo do
  @shortdoc "Direct session → badge → dual consent → morph → warm packet"
  @moduledoc """
  Runs the Mazel spine v0 demo with two mock agents.

      mix demo
  """
  use Mix.Task

  @impl true
  def run(_args) do
    System.put_env("MAZEL_HTTP", "0")
    Mix.Task.run("app.start")
    Room.Demo.print()
    :ok
  end
end
