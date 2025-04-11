defmodule AsteriskConnector do
  use Application

  def start(_type, _args) do
    ami_config = Application.get_env(:asterisk_connector, :ami)

    children = [
      {ElixirAmi.Connection, Map.new(ami_config)},
      AsteriskConnector.AmiListener,
      AsteriskConnector.AmiEventRouter,
      {Plug.Cowboy, scheme: :http, plug: AsteriskConnector.Api, options: [port: 4001]}
    ]

    opts = [strategy: :one_for_one, name: AsteriskConnector.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
