defmodule AsteriskConnector do
  use Application

  def start(_type, _args) do
    children = [
      AsteriskConnector.AmiEventHandler,
      {Plug.Cowboy, scheme: :http, plug: FakeCRM, options: [port: 4001]}
    ]

    opts = [strategy: :one_for_one, name: AsteriskConnector.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
