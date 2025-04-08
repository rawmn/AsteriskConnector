defmodule AsteriskConnector.AmiEventHandler do
  use GenServer
  require Logger

  def start_link(_) do
    Logger.debug("AsteriskConnector.AmiHandler start")

    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_arg) do
    connect()
    {:ok, init_arg}
  end

  def connect(username \\ "test", secret \\ "123") do
    ElixirAmi.Supervisor.Ami.new(%{
      name: :asterisk_connection,
      host: "127.0.0.1",
      port: 5038,
      username: username,
      password: secret,
      debug: false,
      ssl_options: nil,
      connect_timeout: 5000,
      reconnect_timeout: 5000
    })

    ElixirAmi.Connection.add_listener(
      :asterisk_connection,
      &filter_events/3,
      &handle_event/3
    )
  end

  def handle_cast({:new_event, event}, active_calls) do
    active_calls
    |> Map.get(event.keys["linkedid"])
    |> send_event(event)

    {
      :noreply,
      active_calls
    }
  end

  defp send_event(nil, event) do
    GenServer.cast(__MODULE__, {:new_call, event})
  end

  defp send_event(pid, event) do
    GenServer.cast(pid, {:event, event})
  end

  def handle_cast({:new_call, event}, active_calls) do
    {:ok, pid} = AsteriskConnector.CallDetail.start()
    send_event(pid, event)

    {
      :noreply,
      Map.put(active_calls, event.keys["linkedid"], pid)
    }
  end

  def handle_cast({:call_ended, linkedid}, active_calls) do
    {:noreply, Map.delete(active_calls, linkedid)}
  end

  def handle_call(:get_active_calls, _, active_calls) do
    {
      :reply,
      active_calls,
      active_calls
    }
  end

  defp filter_events(_, _, %ElixirAmi.Event{keys: %{"linkedid" => _}}), do: true
  defp filter_events(_, _, _), do: false

  defp handle_event(_, _, event) do
    AsteriskConnector.EventLogger.log_event(event)
    GenServer.cast(__MODULE__, {:new_event, event})
  end

  def get_active_calls() do
    GenServer.call(__MODULE__, :get_active_calls)
    |> Map.values()
    |> Enum.map(&AsteriskConnector.CallDetail.get_call_details/1)
  end
end
