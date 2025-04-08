defmodule AsteriskConnector.Api do
  def send_history(call_details) do
    body = %{
      # type: ,
      # user: ,
      phone: call_details.caller.number,
      diversion: call_details.callee.number,
      start: call_details.timestamps.start,
      duration: call_details.timestamps.duration_call,
      call_id: call_details.call_id,
      status: call_details.status,
      ext: call_details.exten,
      # group_real_name: ,
      # telnum: ,
      link: call_details.record_link
      # telnum_name: ,
      # rating: call_details.rating
    }

    Req.post("http://localhost:4001/call_details/", json: body)
    |> handle_response()
  end

  def send_event(:start, call_details) do
    body = %{
      # type: "start",
      call_id: call_details.call_id,
      phone: call_details.caller.number,
      # user: ,
      # direction: ,
      diversion: call_details.callee.number,
      ext: call_details.exten,
      # group_real_name: ,
      # telnum: ,
      # telnum_name: ,
    }

    Req.post("http://localhost:4001/call_start/", json: body)
    #|> handle_response()
  end

  def send_event(:answer, call_details) do
    body = %{
      # type: "answer",
      call_id: call_details.call_id,
      phone: call_details.caller.number,
      # user: ,
      # direction: ,
      diversion: call_details.callee.number,
      ext: call_details.exten,
      # group_real_name: ,
      # telnum: ,
      # telnum_name: ,
    }

    Req.post("http://localhost:4001/call_answer/", json: body)
    #|> handle_response()
  end

  def send_event(:end, call_details) do
    body = %{
      # type: "end",
      call_id: call_details.call_id,
      phone: call_details.caller.number,
      # user: ,
      # direction: ,
      diversion: call_details.callee.number,
      ext: call_details.exten,
      # group_real_name: ,
      # telnum: ,
      # telnum_name: ,
    }

    Req.post("http://localhost:4001/call_end/", json: body)
    #|> handle_response()
  end

  def get(url) do
    Req.get(url)
    |> handle_response()
  end

  defp handle_response({:ok, %{body: body}}) do
    IO.puts("Ответ: #{inspect(body)}")
    {:ok, body}
  end

  defp handle_response({:error, reason}) do
    IO.puts("Ответ: #{reason}")
    {:error, reason}
  end
end
