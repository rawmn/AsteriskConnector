import Config

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

config :asterisk_connector, :api,
  url_crm_api: ""
