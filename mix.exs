defmodule EctoGQL.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_gql,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.3"},
      {:ecto_sql, "~> 3.3"},
      {:absinthe, "~> 1.4"},
      {:paginator, github: "duffelhq/paginator", ref: "6740061bf629e4d7a460d581a390b52f3bebf76c"}
    ]
  end
end
