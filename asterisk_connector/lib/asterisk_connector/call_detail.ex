defmodule AsteriskConnector.CallDetail do
  defstruct call_id: nil,
            account_code: nil,
            caller: %{
              name: nil,
              number: nil,
              channel: nil
            },
            callee: %{
              name: nil,
              number: nil,
              channel: nil
            },
            timestamps: %{
              start: nil,
              answer: nil,
              end: nil,
              duration_call: nil,
              duration_answer: nil,
              duration_ring: nil
            },
            exten: nil,
            context: nil,
            status: nil,
            last_channel_state: nil,
            who_hangup: nil,
            record_link: nil,
            bridge_id: nil,
            rating: nil,
            quality_metrics: %{
              max_rtt: 0.0,
              max_loss: 0,
              r_factor: nil,
              quality: nil
            }

  use GenServer

  def start() do
    GenServer.start_link(__MODULE__, %AsteriskConnector.CallDetail{})
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_cast(
        {:event,
         %{event: "newchannel", keys: %{"linkedid" => linkedid, "uniqueid" => linkedid} = keys}},
        details
      ) do
    new_details = %{
      details
      | call_id: keys["linkedid"],
        account_code: keys["accountcode"],
        caller: %{
          name: keys["calleridname"],
          number: keys["calleridnum"],
          channel: keys["channel"]
        },
        context: keys["context"],
        exten: keys["exten"],
        timestamps: %{details.timestamps | start: DateTime.utc_now()},
        last_channel_state: keys["channelstatedesc"]
    }

    AsteriskConnector.Api.send_event(:start, new_details)
    {:noreply, new_details}
  end

  def handle_cast({:event, %{event: "newchannel", keys: keys}}, details) do
    {:noreply,
     %{
       details
       | callee: %{
           name: keys["calleridname"],
           number: keys["calleridnum"],
           channel: keys["channel"]
         },
         last_channel_state: keys["channelstatedesc"]
     }}
  end

  def handle_cast(
        {:event,
         %{event: "bridgeenter", keys: %{"linkedid" => linkedid, "uniqueid" => linkedid} = keys}},
        details
      ) do
    answer_time = DateTime.utc_now()
    start_time = details.timestamps.start

    record_link = start_recording_call(keys["channel"], details)

    new_details = %{
      details
      | timestamps: %{
          details.timestamps
          | answer: answer_time,
            duration_ring: DateTime.diff(answer_time, start_time)
        },
        last_channel_state: keys["channelstatedesc"],
        bridge_id: keys["bridgeuniqueid"],
        record_link: record_link
    }

    AsteriskConnector.Api.send_event(:answer, new_details)
    {:noreply, new_details}
  end

  def start_recording_call(channel, call_details) do
    file_name =
      "#{call_details.caller.name}_#{call_details.callee.name}_#{Date.utc_today()}#{call_details.call_id}.wav"

    path =
      Path.expand("priv/recordings/#{file_name}")

    action = ElixirAmi.Action.new("MixMonitor", %{channel: channel, file: path})
    ElixirAmi.Connection.send_action(:asterisk_connection, action)
    record_link = "http://localhost:4001/recordings/#{file_name}"
  end

  def handle_cast({:event, %{event: "hanguprequest", keys: keys}}, details) do
    {
      :noreply,
      %{
        details
        | last_channel_state: keys["channelstatedesc"],
          who_hangup:
            "name:#{keys["calleridname"]};num:#{keys["calleridnum"]};channel:#{keys["channel"]}"
      }
    }
  end

  def handle_cast(
        {:event, %{event: "varset", keys: %{"variable" => "DIALSTATUS", "value" => status}}},
        details
      ) do
    {
      :noreply,
      %{details | status: status}
    }
  end

  def handle_cast(
        {:event,
         %{event: "hangup", keys: %{"linkedid" => linkedid, "uniqueid" => linkedid} = keys}},
        details
      ) do
    end_time = DateTime.utc_now()
    start_time = details.timestamps.start
    answer_time = details.timestamps.answer
    duration_answer = if is_nil(answer_time), do: 0, else: DateTime.diff(end_time, answer_time)
    duration_call = DateTime.diff(end_time, start_time)

    new_details = %{
      details
      | timestamps: %{
          details.timestamps
          | end: end_time,
            duration_answer: duration_answer,
            duration_call: duration_call
        },
        last_channel_state: keys["channelstatedesc"]
    }

    AsteriskConnector.Api.send_event(:end, new_details)
    AsteriskConnector.Api.send_history(new_details)
    {:stop, :normal, new_details}
  end

  def handle_cast({:event, %{event: "rtcpreceived", keys: %{"pt" => "200(SR)"} = keys}}, details) do
    new_quality_metrics = calculate_new_metrics(details.quality_metrics, keys)
    {:noreply, %{details | quality_metrics: new_quality_metrics}}
  end

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
          |> loss_calc(sent)
          |> max(current_metrics.max_loss)
      end

    r_factor = 100 - (max_rtt / 10 + 2 * max_loss)

    %{max_rtt: max_rtt, max_loss: max_loss, r_factor: r_factor, quality: quality(r_factor)}
  end

  defp loss_calc(loss, sent) do
    loss
    |> String.to_integer()
    |> Kernel./(sent)
    |> Kernel.*(100)
  end

  defp quality(r_factor) when r_factor >= 80, do: "good"
  defp quality(r_factor) when r_factor >= 60, do: "medium"
  defp quality(_), do: "low"

  def handle_cast({:event, %{event: "dtmfbegin", keys: keys}}, details) do
    {:noreply, %{details | rating: keys["digit"]}}
  end

  def handle_cast({:event, event}, details) do
    {:noreply, details}
  end

  def handle_call(:get_details, _, details) do
    {:reply, details, details}
  end

  def terminate(reason, details) do
    GenServer.cast(AsteriskConnector.AmiEventHandler, {:call_ended, details.call_id})
  end

  def get_call_details(pid) do
    GenServer.call(pid, :get_details)
  end
end
