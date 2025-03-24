defmodule AsteriskConnector.Client do
  require ElixirAmi.Connection

  @connection_name :asterisk_conn

  def login(username, secret) do
    ElixirAmi.Connection.start_link(%{
      name: @connection_name,
      host: "127.0.0.1",
      port: 5038,
      username: username,
      password: secret,
      debug: false,
      ssl_options: nil,
      connect_timeout: 5000,
      reconnect_timeout: 5000
    })
  end

  def logoff do
    ElixirAmi.Connection.send_action(@connection_name,ElixirAmi.Action.logoff())
  end

  def ping do
    ElixirAmi.Connection.send_action(@connection_name,ElixirAmi.Action.ping())
  end

  def show_dialplan do
    ElixirAmi.Connection.send_action(@connection_name,ElixirAmi.Action.new("ShowDialPlan")) #
  end

  def test_log do
    state = %{
      info: %{
        name: "MyApp",
        debug: true
      }
    }

    ElixirAmi.Connection.log(:debug, "This is a debug message")
    ElixirAmi.Connection.log(:info, "This is an info message")
  end
end
