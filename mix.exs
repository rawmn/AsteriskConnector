defmodule AsteriskConnector.MixProject do
  use Mix.Project

  def project do
    [
      app: :asterisk_connector,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {AsteriskConnector, []},
      extra_applications: [:logger, :elixir_ami, :wx, :observer, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:ex_ami, "~> 0.3.3"}
      {:elixir_ami, "~> 0.0.20"},
      {:plug_cowboy, "~> 2.6"},
      {:ecto_sql, "~> 3.12.1"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.10"},
      {:nadia, "~> 0.7.0"}
    ]
  end
end
