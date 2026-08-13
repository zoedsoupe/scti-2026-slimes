defmodule SlimesWeb.SocketHandler do
  require Logger

  @behaviour WebSock

  @impl true
  def init(assigns) do
    Logger.info("==> ws conn ready")
    {:ok, assigns}
  end

  @impl true
  def handle_in({"ping", [opcode: :text]}, state) do
    {:push, {:text, "pong"}, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:ok, state}
  end
end
