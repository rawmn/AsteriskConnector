defmodule AsteriskConnector.Repo do
  use Ecto.Repo,
    otp_app: :asterisk_connector,
    adapter: Ecto.Adapters.Postgres
end
