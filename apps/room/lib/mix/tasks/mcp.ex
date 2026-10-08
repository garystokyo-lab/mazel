defmodule Mix.Tasks.Mcp do
  @shortdoc "Run Mazel MCP server on stdio"
  @moduledoc """
  JSON-RPC MCP over stdio. Cursor, Grok, Hermes, and Muse point here.

      mix mcp
  """
  use Mix.Task

  @impl true
  def run(_args) do
    System.put_env("MAZEL_HTTP", "0")
    System.put_env("MAZEL_MCP", "1")
    Mix.Task.run("app.start")
    Room.Mcp.stdio()
  end
end
