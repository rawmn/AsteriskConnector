defmodule AsteriskConnector.Router do
  use Plug.Router
  require Logger

  plug(:match)
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug(:dispatch)

  post "/connect" do
    case conn.body_params do
      %{"username" => user, "password" => pass} ->
        case AsteriskConnector.Client.login(user, pass) do
          {:ok, _} ->
            send_resp(conn, 200, Jason.encode!(%{response: "connected"}))

          {:error, reason} ->
            send_resp(conn, 500, Jason.encode!(%{response: "failed to connect", reason: inspect(reason)}))
        end

      _ ->
        send_resp(conn, 400, Jason.encode!(%{error: "Неправильные параметыр"}))
    end
  end

  get "/ping" do
    case AsteriskConnector.Client.ping() do
      %ElixirAmi.Response{keys: %{"ping" => response}} ->
        Logger.info("Получен ping от клиента — ответ: #{inspect(response)}")
        send_resp(conn, 200, Jason.encode!(%{response: response}))
    end
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
