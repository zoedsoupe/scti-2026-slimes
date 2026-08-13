defmodule Slimes.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Bandit, plug: SlimesWeb.Router}
    ]

    opts = [strategy: :one_for_one, name: Slimes.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
