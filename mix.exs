defmodule DevTodo.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/elixir-saas/dev_todo"

  def project do
    [
      app: :dev_todo,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      description:
        "A file-backed Kanban board for Elixir projects. TODO.md is the source of truth.",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:file_system, "~> 1.0"},
      {:nimble_parsec, "~> 1.4"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:esbuild, "~> 0.5", only: :dev},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1,
       only: :dev},
      {:tailwind, "~> 0.3", only: :dev},
      {:tailwind_formatter, "~> 0.4", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Justin"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib dist mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "DevTodo",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      "assets.build": ["esbuild default --minify", "tailwind default --minify"],
      "assets.watch": ["assets.watch"]
    ]
  end
end
