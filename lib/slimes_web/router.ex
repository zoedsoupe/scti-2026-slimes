defmodule SlimesWeb.Router do
  use Plug.Router

  alias SlimesWeb.SocketHandler

  plug(Plug.Logger)
  plug(Plug.Static, at: "/", from: {:slimes, "priv/projector"})
  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_file(200, Application.app_dir(:slimes, "priv/projector/index.html"))
  end

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
    |> put_resp_header("content-type", "application/zip")
    |> send_file(200, Application.app_dir(:slimes, "priv/student-kit.zip"))
  end

  match _ do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(404, ~s|{"message": "Not Found"}|)
  end
end
