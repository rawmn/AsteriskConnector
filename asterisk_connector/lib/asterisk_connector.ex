defmodule AsteriskConnector do
  use Application

  def start(_type, _args) do
    children = [
      # AsteriskConnector.AmiHandler,
      # {ElixirAmi.Connection, %{
      #   name: :asterisk_conn,
      #   host: "127.0.0.1",
      #   port: 5038,
      #   username: "test",
      #   password: "123",
      #   debug: false,
      #   ssl_options: nil,
      #   connect_timeout: 5000,
      #   reconnect_timeout: 5000,
      #   event_handlers: [Conn.AmiHandler]
      # }},
      {Plug.Cowboy, scheme: :http, plug: AsteriskConnector.Router, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: AsteriskConnector.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
