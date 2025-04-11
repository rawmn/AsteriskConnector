defmodule AsteriskConnector.AmiListener do
  use GenServer
  require Logger

  def start_link(_) do
    Logger.debug("AsteriskConnector.AmiListener: Starting")
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, setup_listener()}
  end

  def terminate(_reason, listener_id) do
    ElixirAmi.Connection.del_listener(
      Keyword.get(Application.get_env(:asterisk_connector, :ami), :name),
      listener_id
    )
  end

  defp setup_listener() do
    ElixirAmi.Connection.add_listener(
      Keyword.get(Application.get_env(:asterisk_connector, :ami), :name),
      &filter_events/3,
      fn
        _, _, event ->
          AsteriskConnector.EventLogger.log_event(event)
          AsteriskConnector.AmiEventRouter.new_event(event)
      end
    )
  end

  defp filter_events(_, _, %ElixirAmi.Event{keys: %{"linkedid" => _}}), do: true
  defp filter_events(_, _, _), do: false
end
