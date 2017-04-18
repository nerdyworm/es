defmodule Es.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      worker(ES.Cache, []),

      # TODO - should probably remove me
      #Plug.Adapters.Cowboy.child_spec(:http, ES.Plug.Router, [], [port: 4000])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Es.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
