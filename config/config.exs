import Config

config :asterisk_connector, AsteriskConnector.Repo,
  database: "asterisk_connector_repo",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  migration_lock: nil,
  migration_primary_key: [name: :id, type: :bigserial],
  migration_foreign_key: [column: :id, type: :bigserial]

config :asterisk_connector, ecto_repos: [AsteriskConnector.Repo]

config :asterisk_connector, :ami,
  name: :asterisk_connection,
  host: "127.0.0.1",
  port: 5038,
  username: "test",
  password: "123",
  ssl_options: nil,
  debug: nil,
  connect_timeout: 5000,
  reconnect_timeout: 5000

config :asterisk_connector, :priority, "1"

config :asterisk_connector, :context, "org_all"

config :asterisk_connector, url_crm_api: "http://localhost:4040/crm_api/"

config :nadia,
  token: "7188979851:AAFllFbsMyBhoUU8rJuILPBHTtJkXnhFbKU"
