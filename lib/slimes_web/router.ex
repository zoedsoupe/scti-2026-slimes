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

  get "/kit" do
    conn
    |> put_resp_header("content-type", "application/zip")
    |> put_resp_header("content-disposition", ~s(attachment; filename="student-kit.zip"))
    |> send_file(200, Application.app_dir(:slimes, "priv/student-kit.zip"))
  end

  @langs ~w(elixir golang c python)

  for l <- @langs do
    get "/kit/#{l}" do
      conn
      |> put_resp_header("content-type", "application/zip")
      |> put_resp_header("content-disposition", ~s(attachment; filename="student-kit-#{unquote(l)}.zip"))
      |> send_file(200, Application.app_dir(:slimes, "priv/student-kit-#{unquote(l)}.zip"))
    end
  end

  match _ do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(404, ~s|{"message": "Not Found"}|)
  end
end
