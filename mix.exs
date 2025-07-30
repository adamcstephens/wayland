defmodule WaylandClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :wayland_client,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:rustler] ++ Mix.compilers(),
      rustler_crates: [
        wayland_client_nif: [
          path: "native/wayland_client",
          mode: rustler_mode(Mix.env())
        ]
      ],
      package: package(),
      description: description(),
      source_url: "https://github.com/adamcstephens/wayland",
      docs: [
        main: "WaylandClient",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.30"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp rustler_mode(:prod), do: :release
  defp rustler_mode(_), do: :debug

  defp description do
    "Elixir library for building Wayland clients using Rustler and Smithay wayland-client"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/adamcstephens/wayland"}
    ]
  end
end