defmodule AsteriskConnector.Api do
  require Logger
  require Ecto.Query
  alias AsteriskConnector.Helper, as: Helper
  alias AsteriskConnector.DbFunctions, as: DbFunctions
  use Plug.Router

  plug(Plug.Static, at: "/recordings", from: "priv/recordings/")
  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "Welcome to Asterisk Connector API")
  end

  post "/api/missedcalls" do
    with {:ok, params} <- Helper.parse_body(conn),
         {:ok, callee} <- Helper.get_required_param(params, "callee") do
      missed_calls = DbFunctions.get_missed_calls(callee)

      case Jason.encode(missed_calls) do
        {:ok, json} ->
          send_resp(conn, 200, json)

        {:error, reason} ->
          Logger.error("Cannot be converted to json: #{reason}")
          send_resp(conn, 400, reason)
      end
    else
      {:error, reason} ->
        Logger.error("Failed to get missed calls: #{reason}")
        send_resp(conn, 400, reason)
    end
  end

  post "/api/setname" do
    # TODO: get name from external service and set this name for channel.
  end

  post "/api/redirect" do
    with {:ok, params} <- Helper.parse_body(conn),
         {:ok, channel} <- Helper.get_required_param(params, "channel"),
         {:ok, exten} <- Helper.get_required_param(params, "exten"),
         extra_channel <- Map.get(params, "extra_channel"),
         extra_exten <- Map.get(params, "extra_exten") do
      case Helper.redirect_call(channel, exten, extra_channel, extra_exten) do
        {:ok, message} -> send_resp(conn, 200, message)
        {:error, reason} -> send_resp(conn, 500, reason)
      end
    else
      {:error, reason} ->
        Logger.error("Failed to redirect call: #{reason}")
        send_resp(conn, 400, reason)
    end
  end

  post "/api/transfer" do
    with {:ok, params} <- Helper.parse_body(conn),
         {:ok, channel} <- Helper.get_required_param(params, "channel"),
         {:ok, exten} <- Helper.get_required_param(params, "exten") do
      case Helper.transfer_call(channel, exten) do
        {:ok, message} -> send_resp(conn, 200, message)
        {:error, reason} -> send_resp(conn, 500, reason)
      end
    else
      {:error, reason} ->
        Logger.error("Failed to transfer call: #{reason}")
        send_resp(conn, 400, reason)
    end
  end

  post "/api/originate" do
    with {:ok, params} <- Helper.parse_body(conn),
         {:ok, caller} <- Helper.get_required_param(params, "caller"),
         {:ok, callee} <- Helper.get_required_param(params, "callee"),
         caller_name <- Map.get(params, "caller_name", caller) do
      case Helper.originate_call(caller, callee, caller_name) do
        {:ok, message} -> send_resp(conn, 200, message)
        {:error, reason} -> send_resp(conn, 500, reason)
      end
    else
      {:error, reason} ->
        Logger.error("Failed to originate call: #{reason}")
        send_resp(conn, 400, reason)
    end
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
