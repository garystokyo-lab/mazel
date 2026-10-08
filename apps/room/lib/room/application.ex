defmodule Room.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Phoenix.PubSub, name: Room.PubSub},
        {Registry, keys: :unique, name: Room.Registry},
        {DynamicSupervisor, name: Room.Contexts, strategy: :one_for_one}
      ] ++ http_child()

    Supervisor.start_link(children, strategy: :one_for_one, name: Room.Supervisor)
  end

  defp test_env? do
    function_exported?(Mix, :env, 0) and Mix.env() == :test
  end

  defp http_child do
    if System.get_env("MAZEL_HTTP") == "0" or test_env?() do
      []
    else
      port = String.to_integer(System.get_env("PORT") || "4747")

      [
        {Bandit,
         plug: Room.Http,
         scheme: :http,
         port: port,
         thousand_island_options: [transport_options: [ip: {0, 0, 0, 0}]]}
      ]
    end
  end
end
