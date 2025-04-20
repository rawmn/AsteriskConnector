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
      #&handle_event/3
      fn
        _, _, event ->
          AsteriskConnector.EventLogger.log_event(event)
          AsteriskConnector.AmiEventRouter.new_event(event)
      end
    )
  end

  defp filter_events(_, _, %ElixirAmi.Event{keys: %{"linkedid" => _}}), do: true
  # defp filter_events(_, _, _), do: false
  defp filter_events(_, _, _), do: true

  defp handle_event(_, _, event) do
    cond do
      event.event in ~w"softhanguprequest devicestatechange fullybooted varset testevent rtcpsent rtcpreceived successfulauth challengesent" ->
        nil

      event.keys["variable"] in ~w"RTPAUDIOQOS RTPAUDIOQOSJITTER RTPAUDIOQOSLOSS RTPAUDIOQOSRTT RTPAUDIOQOSMES BRIDGEPEER BRIDGEPVTCALLID RTPAUDIOQOS RTPAUDIOQOSBRIDGED RTPAUDIOQOSJITTER RTPAUDIOQOSJITTERBRIDGED RTPAUDIOQOSLOSS RTPAUDIOQOSLOSSBRIDGED RTPAUDIOQOSRTT RTPAUDIOQOSRTTBRIDGED RTPAUDIOQOSMES RTPAUDIOQOSMESBRIDGED BRIDGEPEER" ->
        nil

      event.event in ~w"blindtransfer newchannel" ->
        IO.inspect("-------------------------------")
        IO.inspect(event, pretty: true)
        IO.inspect("-------------------------------")

      true ->
        nil
    end
  end

  # action = ElixirAmi.Action.new("Redirect", %{channel: "PJSIP/101-00000028", exten: "103", context: "org_all", priority: "1"})
end
