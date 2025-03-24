defmodule AsteriskConnector.AmiHandler do
  use GenServer
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    Logger.debug("Conn.AmiHandler init")
    {:ok, state}
  end

  def handle_info({:ami_event, event}, state) do
    Logger.info("Получено AMI событие: #{inspect(event)}")
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Непонятно что: #{inspect(msg)}")
    {:noreply, state}
  end

  def handle_call({:send, action}, _from, state) do
    Logger.debug("asdadasdsadasdsadsa: #{action}\n#{state}")
  end
end
