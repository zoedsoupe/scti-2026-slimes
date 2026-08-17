defmodule Slimes.MixProject do
  use Mix.Project

  def project do
    [
      app: :slimes,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Slimes.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:websock_adapter, "~> 0.6"},
      {:plug, "~> 1.20"},
      {:bandit, "~> 1.12"},
      {:peri, "~> 0.9"}
    ]
  end
end
