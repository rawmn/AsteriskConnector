defmodule AsteriskConnector do
  use Application

  def start(_type, _args) do
    ami_config = Application.get_env(:asterisk_connector, :ami)

    ensure_database_created()

    children = [
      {Task, &AsteriskConnector.TelegramBot.start/0},
      AsteriskConnector.Repo,
      {ElixirAmi.Connection, Map.new(ami_config)},
      AsteriskConnector.AmiListener,
      AsteriskConnector.AmiEventRouter,
      {Plug.Cowboy, scheme: :http, plug: AsteriskConnector.Api, options: [port: 4001]}
    ]

    with {:ok, supervisor} <- Supervisor.start_link(children, strategy: :one_for_one) do
      run_pending_migrations()
      {:ok, supervisor}
    end
  end

  defp ensure_database_created do
    config = Application.get_env(:asterisk_connector, AsteriskConnector.Repo)

    {:ok, conn} =
      Postgrex.start_link(
        hostname: config[:hostname],
        username: config[:username],
        password: config[:password],
        database: "postgres",
        port: config[:port]
      )

    case Postgrex.query(conn, "SELECT 1 FROM pg_database WHERE datname = $1", [config[:database]]) do
      {:ok, %{rows: []}} ->
        Postgrex.query!(conn, "CREATE DATABASE #{config[:database]}", [])

      _ ->
        nil
    end

    Process.exit(conn, :normal)
  end

  defp run_pending_migrations do
    repos = Application.get_env(:asterisk_connector, :ecto_repos)

    for repo <- repos do
      case Ecto.Migrator.with_repo(repo, &Ecto.Migrator.migrations/1) do
        [] ->
          nil

        _pending_migrations ->
          Ecto.Migrator.run(repo, "priv/repo/migrations", :up, all: true)
      end
    end
  end
end
