defmodule AsteriskConnector.ApiRequest do
  require Logger
  def send_history(call_details) do
    body = %{
      cmd: "history",
      phone: call_details.caller.number,
      diversion: call_details.callee.number,
      start: call_details.timestamps.start,
      duration: call_details.timestamps.duration_call,
      call_id: call_details.call_id,
      status: call_details.status,
      ext: call_details.exten,
      link: call_details.record_link,
      rating: call_details.rating
    }

    Req.post(Application.get_env(:asterisk_connector, :url_crm_api), json: body)
    |> handle_response("history")
  end

  def send_event(call_details, cmd) when cmd in ~w"start answer end" do
    body = %{
      cmd: cmd,
      call_id: call_details.call_id,
      phone: call_details.caller.number,
      diversion: call_details.callee.number,
      ext: call_details.exten
    }

    Req.post(Application.get_env(:asterisk_connector, :url_crm_api), json: body)
    |> handle_response(cmd)
  end

  def send_event(_call_details, cmd) do
    Logger.error("Unexpected command: #{cmd}")
  end

  defp handle_response({:ok, %{body: body}}, cmd) do
    Logger.debug("Command: #{cmd}\nResponse: #{inspect(body)}")
    {:ok, body}
  end

  defp handle_response({:error, reason}, cmd) do
    Logger.error("Command: #{cmd}\nError response: #{inspect(reason)}")
    {:error, reason}
  end
end
