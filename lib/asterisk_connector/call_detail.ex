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

  require Logger
  require Ecto.Query

  alias AsteriskConnector.Helper, as: Helper
  alias AsteriskConnector.DbFunctions, as: DbFunctions

  use GenServer

  def start() do
    GenServer.start_link(__MODULE__, %AsteriskConnector.CallDetail{})
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def event_receiver(pid, event) do
    GenServer.cast(pid, {:event, event})
  end

  def get_call_details(pid) do
    GenServer.call(pid, :get_details)
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

    IO.inspect(new_details.caller.channel, label: "channel")

    AsteriskConnector.ApiRequest.send_event(new_details, "start")
    {:noreply, new_details}
  end

  def handle_cast({:event, %{event: "blindtransfer", keys: keys}}, details) do
    DbFunctions.get_chat_id(keys["extension"])
    |> case do
      nil -> nil
      chat_id -> AsteriskConnector.TelegramBot.send_message(chat_id, {:transfer_call, keys})
    end

    {:noreply, details}
  end

  def handle_cast({:event, %{event: "newchannel", keys: keys}}, details) do
    IO.inspect(keys["channel"])

    case DbFunctions.get_chat_id(keys["calleridnum"]) do
      nil -> nil
      chat_id -> AsteriskConnector.TelegramBot.send_message(chat_id, {:start_call, details})
    end

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
    duration_ring = if is_nil(start_time), do: nil, else: DateTime.diff(answer_time, start_time)

    record_link = Helper.start_recording_call(keys["channel"], details)

    new_details = %{
      details
      | timestamps: %{
          details.timestamps
          | answer: answer_time,
            duration_ring: duration_ring
        },
        last_channel_state: keys["channelstatedesc"],
        bridge_id: keys["bridgeuniqueid"],
        record_link: record_link
    }

    AsteriskConnector.ApiRequest.send_event(new_details, "answer")
    {:noreply, new_details}
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
    cond do
      status in ~w"BUSY NOANSWER" ->
        DbFunctions.get_chat_id(details.callee.number)
        |> case do
          nil -> nil
          chat_id -> AsteriskConnector.TelegramBot.send_message(chat_id, {:missed_call, details})
        end

      true ->
        nil
    end

    {
      :noreply,
      %{details | status: status}
    }
  end

  # def handle_cast(
  #       {:event,
  #        %{event: "bridgeleave", keys: %{"linkedid" => linkedid, "uniqueid" => linkedid} = keys}},
  #       details
  #     ) do
  #   end_time = DateTime.utc_now()
  #   start_time = details.timestamps.start
  #   answer_time = details.timestamps.answer
  #   duration_answer = if is_nil(answer_time), do: nil, else: DateTime.diff(end_time, answer_time)
  #   duration_call = if is_nil(start_time), do: nil, else: DateTime.diff(end_time, start_time)

  #   new_details = %{
  #     details
  #     | timestamps: %{
  #         details.timestamps
  #         | end: end_time,
  #           duration_answer: duration_answer,
  #           duration_call: duration_call
  #       },
  #       last_channel_state: keys["channelstatedesc"]
  #   }

  #   case DbFunctions.insert_db(new_details) do
  #     {:ok, _} -> Logger.debug("Database: Insertion completed")
  #     {_, error} -> Logger.error("Database: Insertion error: #{inspect(error.errors)}")
  #   end

  #   AsteriskConnector.ApiRequest.send_event(new_details, "end")
  #   {:noreply, new_details}
  # end

  def handle_cast(
        {:event,
         %{event: "hangup", keys: %{"linkedid" => linkedid, "uniqueid" => linkedid} = keys}},
        details
      ) do
    end_time = DateTime.utc_now()
    start_time = details.timestamps.start
    answer_time = details.timestamps.answer
    duration_answer = if is_nil(answer_time), do: nil, else: DateTime.diff(end_time, answer_time)
    duration_call = if is_nil(start_time), do: nil, else: DateTime.diff(end_time, start_time)

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

    case DbFunctions.insert_db(new_details) do
      {:ok, _} -> Logger.debug("Database: Insertion completed")
      {_, error} -> Logger.error("Database: Insertion error: #{inspect(error.errors)}")
    end

    AsteriskConnector.ApiRequest.send_event(new_details, "end")
    AsteriskConnector.ApiRequest.send_history(new_details)
    {:stop, :normal, new_details}
  end

  def handle_cast({:event, %{event: "rtcpreceived", keys: %{"pt" => "200(SR)"} = keys}}, details) do
    new_quality_metrics = Helper.calculate_new_metrics(details.quality_metrics, keys)
    {:noreply, %{details | quality_metrics: new_quality_metrics}}
  end

  def handle_cast({:event, %{event: "dtmfbegin", keys: keys}}, details) do
    {:noreply, %{details | rating: keys["digit"]}}
  end

  def handle_cast({:event, _event}, details) do
    {:noreply, details}
  end

  def handle_call(:get_details, _, details) do
    {:reply, details, details}
  end

  def terminate(_reason, details) do
    AsteriskConnector.AmiEventRouter.call_ended(details.call_id)
  end
end
