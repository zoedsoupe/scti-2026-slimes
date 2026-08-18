defmodule SlimesWeb.Router do
  use Plug.Router

  alias SlimesWeb.SocketHandler

  plug(Plug.Logger)
  plug(Plug.Static, at: "/", from: {:slimes, "projector"})
  plug(:match)
  plug(:dispatch)

  get "/ws" do
    conn
    |> WebSockAdapter.upgrade(SocketHandler, [], [])
    |> halt()
  end

  get "/debug/log" do
    conn
    |> put_resp_header("content-type", "application/x-ndjson")
    |> send_resp(200, Slimes.World.export(Slimes.World))
  end

  get "/kit.zip" do
    conn
    |> put_resp_header("content-type", "text/plain")
    |> send_resp(200, "here are your kit!")
  end

  match _ do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(404, ~s|{"message": "Not Found"}|)
  end
end
