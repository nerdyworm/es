defmodule Es.Mixfile do
  use Mix.Project

  def project do
    [app: :es,
     version: "0.1.0",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Es.Application, []}]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
     {:ex_aws, "~> 1.0"},
     {:ex_kcl, github: "nerdyworm/ex_kcl"},
     #{:ex_kcl, path: "/Users/benjamin/code/ex_kcl"},
     {:poison, "~> 2.0"},
     {:uuid, "~> 1.1"},
     {:postgrex, ">= 0.0.0"},
     {:ecto, "> 0.0.0"},

      # for admin
      {:cowboy, "~> 1.0"},
      {:plug, ">= 1.0.0"},
      {:cors_plug, ">= 1.0.0"},

      # streams and good things
      {:gen_stage, "0.11.0"},

      # linting
      {:credo, "~> 0.7", only: [:dev, :test]}
    ]
  end
end
