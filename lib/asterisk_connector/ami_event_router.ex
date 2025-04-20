defmodule AsteriskConnector.AmiEventRouter do
  alias AsteriskConnector.CallDetail, as: CallDetail

  use GenServer
  require Logger

  def start_link(_) do
    Logger.debug("AsteriskConnector.AmiEventRouter: Starting")
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_init_arg) do
    {:ok, %{}}
  end

  def new_event(event) do
    GenServer.cast(__MODULE__, {:new_event, event})
  end

  def new_call(event, linkedid) do
    GenServer.cast(__MODULE__, {:new_call, event, linkedid})
  end

  def call_ended(linkedid) do
    GenServer.cast(__MODULE__, {:call_ended, linkedid})
  end

  def get_active_calls() do
    GenServer.call(__MODULE__, :get_active_calls)
    |> Map.values()
    |> Enum.map(&CallDetail.get_call_details/1)
  end

  defp transfer_event(nil, event) do
    new_call(event, event.keys["linkedid"])
  end

  defp transfer_event(pid, event) do
    CallDetail.event_receiver(pid, event)
  end

  def handle_cast(
        {:new_event,
         %{event: "blindtransfer", keys: %{"transfererlinkedid" => linkedid}} = event},
        active_calls
      ) do
    active_calls
    |> Map.get(linkedid)
    |> transfer_event(event)

    {:noreply, active_calls}
  end

  def handle_cast({:new_event, event}, active_calls) do
    active_calls
    |> Map.get(event.keys["linkedid"])
    |> transfer_event(event)

    {:noreply, active_calls}
  end

  def handle_cast({:new_call, event, linkedid}, active_calls) do
    case CallDetail.start() do
      {:ok, pid} ->
        transfer_event(pid, event)
        {:noreply, Map.put(active_calls, linkedid, pid)}

      {:error, reason} ->
        Logger.error("Failed to start CallDetail process: #{inspect(reason)}")
        {:noreply, active_calls}
    end
  end

  def handle_cast({:call_ended, linkedid}, active_calls) do
    {:noreply, Map.delete(active_calls, linkedid)}
  end

  def handle_call(:get_active_calls, _, active_calls) do
    {:reply, active_calls, active_calls}
  end
end
