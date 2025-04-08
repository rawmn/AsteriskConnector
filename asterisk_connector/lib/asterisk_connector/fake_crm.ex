defmodule FakeCRM do
  use Plug.Router

  plug Plug.Static, at: "/recordings", from: "priv/recordings/"
  plug(:match)
  plug(:dispatch)

  post "/call_start" do
    handle_event(conn, "Звонок начался")
  end

  post "/call_answer" do
    handle_event(conn, "Начался разговор (сняли трубку)")
  end

  post "/call_end" do
    handle_event(conn, "Разговор завершен (положили трубку)")
  end

  post "/call_details" do
    handle_event(conn, "Отправка деталей звонка")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp handle_event(conn, event_name) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    IO.puts("\n--------[#{event_name}]----------\n#{body}")

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
  end
end
