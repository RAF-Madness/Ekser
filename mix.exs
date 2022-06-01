defmodule Kids2022ProjAndrejGasicRn0218.MixProject do
  use Mix.Project

  def project do
    [
      app: :kids_2022_proj_andrej_gasic_rn0218,
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
      mod: {Ekser, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.3"},
      {:png, "~> 0.2.1"}
    ]
  end
end
