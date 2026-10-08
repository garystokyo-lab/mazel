defmodule Room.MixProject do
  use Mix.Project

  def project do
    [
      app: :room,
      version: "0.1.0-dev",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Room.Application, []}
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.6"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.15"}
    ]
  end
end
