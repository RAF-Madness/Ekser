defmodule Ekser.MixProject do
  use Mix.Project

  def project do
    [
      app: :ekser,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Ekser.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:logger_file_backend, "~> 0.0.13"},
      {:jason, "~> 1.3"},
      {:png, "~> 0.2.1"}
    ]
  end
end
