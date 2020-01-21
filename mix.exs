defmodule STL.MixProject do
  use Mix.Project

  def project do
    [
      app: :stl,
      version: "0.1.0",
      elixir: "~> 1.8",
      deps: deps(),
      package: package(),
      description: """
      A library for reading and analyzing ASCII STL 3D model files.
      """
    ]
  end

  def application do
    [
      applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~>0.5.3"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: [
        "Chris Freeze"
      ],
      licenses: ["MIT"],
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      links: %{"GitHub" => "https://github.com/cjfreeze/stl"}
    ]
  end
end
