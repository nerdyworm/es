defmodule Es.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(ES.Cache, []),
    ]

    opts = [strategy: :one_for_one, name: Es.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
