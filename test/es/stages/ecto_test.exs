defmodule ES.Stages.EctoTest do
  use ES.Stages.Case

  defmodule Enricher do
    use GenStage

    def start_link(stream, options) do
      GenStage.start_link(__MODULE__, {stream, options},
        name: Module.concat(stream, __MODULE__))
    end

    def init({stream, options}) do
      subscribe_to = Keyword.get(options, :subscribe_to)
      {:producer_consumer, stream, [subscribe_to: subscribe_to, dispatcher: GenStage.BroadcastDispatcher]}
    end

    def handle_events(events, _from, stream) do
      events = Enum.map(events, &({:enriched, &1}))
      {:noreply, events, stream}
    end
  end

  defmodule Store do
    use ES.EventStore, adapter: ES.Storage.Ecto, repo: ES.Repo
  end

  defmodule Stage do
    use ES.EventStream,
      adapter: ES.Stages.Ecto,
      enrichers: [Enricher, Bloater],
      consumers: [Consumer],
      repo: ES.Repo,
      store: Store
  end

  defmodule App do
    def start do
      import Supervisor.Spec

      children = [
        worker(Stage, []),
      ]

      Supervisor.start_link(children, [
        strategy: :one_for_one,
        max_restarts: 100,
        max_seconds: 1
      ])
    end
  end

  setup_all context do
    {:ok, pid} = App.start

    on_exit(context, fn() ->
      ref = Process.monitor(pid)
      Process.exit(pid, :exit)
      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      end
    end)
  end

  setup do
    Process.register(self(), :testing)
    {:ok, %{stage: Stage}}
  end
end
