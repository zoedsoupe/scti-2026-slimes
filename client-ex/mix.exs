defmodule SlimesClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :slimes_client,
      version: "0.1.0",
      elixir: "~> 1.19",
      deps: [{:websockex, "~> 0.5.1"}]
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
