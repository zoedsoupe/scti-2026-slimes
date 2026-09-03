defmodule Slimes.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    world_opts = [
      name: Slimes.World,
      base_seed: base_seed(),
      mode: if("--no-attacks" in System.argv(), do: :cooperative, else: :tournament)
    ]

    Logger.info("world seed #{world_opts[:base_seed]}, mode #{world_opts[:mode]}")

    children = [
      {Slimes.World, world_opts},
      {Bandit, plug: SlimesWeb.Router, scheme: :http, ip: {0, 0, 0, 0}, port: 4000}
    ]

    opts = [strategy: :one_for_one, name: Slimes.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # seed da partida: SLIMES_SEED para reproduzir, aleatória por padrão
  defp base_seed do
    case System.get_env("SLIMES_SEED") do
      nil -> :rand.uniform(1_000_000)
      seed -> String.to_integer(seed)
    end
  end
end
