defmodule AsteriskConnector.AmiEventHandler do
  require Logger

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start, []},
      type: :worker,
      restart: :permanent
    }
  end

  def start() do
    Logger.debug("AsteriskConnector.AmiHandler start")

    connection =
      ElixirAmi.Supervisor.Ami.new(%{
        name: __MODULE__,
        host: "127.0.0.1",
        port: 5038,
        username: "test",
        password: "123",
        debug: false,
        ssl_options: nil,
        connect_timeout: 5000,
        reconnect_timeout: 5000
      })

    ElixirAmi.Connection.add_listener(
      __MODULE__,
      &filter_events/3,
      &handle_event/3
    )

    connection
  end

  defp via_tuple(name) do
    {:via, :gproc, {:n, :l, {:call, name}}}
  end

  defp filter_events(_, _, _event), do: true

  defp handle_event(_, _, %ElixirAmi.Event{
         event: "newchannel",
         keys:
           %{
             "linkedid" => linkedid,
             "uniqueid" => linkedid
           } = keys
       }) do
    CallDetail.start(linkedid)

    data = %{
      call_id: keys["linkedid"],
      account_code: keys["accountcode"],
      caller: %{
        name: keys["calleridname"],
        number: keys["calleridnum"],
        channel: keys["channel"]
      },
      context: keys["context"],
      exten: keys["exten"],
      start_time: DateTime.utc_now(),
      last_channel_state: keys["channelstatedesc"]
    }

    GenServer.cast(via_tuple(linkedid), {:newchannel, data})
  end

  defp handle_event(_, _, %ElixirAmi.Event{event: "newchannel", keys: keys}) do
    data = %{
      callee: %{
        name: keys["calleridname"],
        number: keys["calleridnum"],
        channel: keys["channel"]
      },
      last_channel_state: keys["channelstatedesc"]
    }

    GenServer.cast(via_tuple(keys["linkedid"]), {:newchannel_callee, data})
  end

  defp handle_event(_, _, %ElixirAmi.Event{
         event: "bridgeenter",
         keys:
           %{
             "linkedid" => linkedid,
             "uniqueid" => linkedid
           } = keys
       }) do
    answer_time = DateTime.utc_now()
    start_time = GenServer.call(via_tuple(linkedid), :get_start_time)

    data = %{
      answer_time: answer_time,
      duration_ring: DateTime.diff(answer_time, start_time),
      last_channel_state: keys["channelstatedesc"]
    }

    GenServer.cast(via_tuple(linkedid), {:bridgeenter, data})
  end

  defp handle_event(_, _, %{event: "hanguprequest", keys: keys}) do
    data = %{
      last_channel_state: keys["channelstatedesc"],
      who_hangup:
        "name:#{keys["calleridname"]};num:#{keys["calleridnum"]};channel:#{keys["channel"]}"
    }

    GenServer.cast(via_tuple(keys["linkedid"]), {:who_hangup_put, data})
  end

  # defp handle_event(_, _, %{event: "varset", keys: %{"variable" => "DIALEDTIME", "value" => duration}}) do

  # end

  # defp handle_event(_, _, %{event: "varset", keys: %{"variable" => "ANSWEREDTIME", "value" => duration}}) do

  # end

  defp handle_event(
         _,
         _,
         %{event: "varset", keys: %{"variable" => "DIALSTATUS", "value" => status} = keys}
       ) do
    GenServer.cast(via_tuple(keys["linkedid"]), {:set_status, status})
  end

  defp handle_event(_, _, %ElixirAmi.Event{
         event: "hangup",
         keys:
           %{
             "linkedid" => linkedid,
             "uniqueid" => linkedid
           } = keys
       }) do
    end_time = DateTime.utc_now()
    start_time = GenServer.call(via_tuple(linkedid), :get_start_time)
    answer_time = GenServer.call(via_tuple(linkedid), :get_answer_time)
    duration_answer = if is_nil(answer_time), do: nil, else: DateTime.diff(end_time, answer_time)

    data = %{
      end_time: end_time,
      duration_answer: duration_answer,
      duration_call: DateTime.diff(end_time, start_time),
      last_channel_state: keys["channelstatedesc"]
    }

    GenServer.cast(via_tuple(linkedid), {:hangup, data})
    test_get_call_struct(keys["linkedid"])
  end

  defp handle_event(_, _, %ElixirAmi.Event{
         event: "rtcpreceived",
         keys: %{"pt" => "200(SR)"} = keys
       }) do
    data =
      GenServer.call(via_tuple(keys["linkedid"]), :get_metrics)
      |> calculate_new_metrics(keys)

    GenServer.cast(via_tuple(keys["linkedid"]), {:rtcpreceived, data})
  end

  defp handle_event(_, _, _), do: nil

  defp calculate_new_metrics(current_metrics, keys) do
    max_rtt =
      case Map.get(keys, "rtt") do
        nil -> current_metrics.max_rtt
        rtt -> max(String.to_float(rtt), current_metrics.max_rtt)
      end

    sent = keys["sentpackets"] |> String.to_integer()

    max_loss =
      case Map.get(keys, "report0cumulativelost") do
        nil ->
          current_metrics.max_loss

        loss ->
          loss
          |> String.to_integer()
          |> Kernel./(sent)
          |> Kernel.*(100)
          |> max(current_metrics.max_loss)
      end

    r_factor = 100 - (max_rtt / 10 + 2 * max_loss)

    quality =
      cond do
        r_factor >= 80 -> "good"
        r_factor >= 60 -> "not good"
        true -> "bad"
      end

    %{max_rtt: max_rtt, max_loss: max_loss, r_factor: r_factor, quality: quality}
  end

  def test_get_call_struct(name) do
    GenServer.call(via_tuple(name), :get)
    |> IO.inspect()
  end

  # defp handle_event(_, _, event) do
  #   case event do
  #     # event.event in ~w"varset testevent successfulauth fullybooted" ->
  #     #   # IO.puts("skip event: #{event.event}")
  #     #   nil

  #     # event.event == "varset" ->
  #     #   IO.puts("----------------------------------------------------------------------")
  #     #   IO.inspect("#{event.keys["variable"]} $ #{event.keys["value"]} $ ", label: "EVENT #{event.keys["calleridnum"]}:", pretty: true)
  #     #   IO.puts("----------------------------------------------------------------------")

  #     %{event: <<?r, ?t, ?c, ?p, _::binary>>, keys: _} ->
  #       IO.puts("----------------------------------------------------------------------")
  #       IO.inspect(event, label: "EVENT:", pretty: true)
  #       IO.puts("----------------------------------------------------------------------")

  #     _ ->
  #       # IO.puts("skip event: #{event.event}")
  #       nil
  #       # IO.puts("----------------------------------------------------------------------")
  #       # IO.inspect(event, label: "EVENT:", pretty: true)
  #       # IO.puts("----------------------------------------------------------------------")
  #   end
  # end
end
