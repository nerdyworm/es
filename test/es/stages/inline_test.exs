defmodule ES.Stages.InlineTest do
  use ES.Stages.Case

  defmodule Enricher do
    def handle_events(events, _from, stream) do
      events = Enum.map(events, &({:enriched, &1}))
      {:noreply, events, stream}
    end
  end

  defmodule Stage do
    use ES.EventStream,
      adapter: ES.Stages.Inline,
      enrichers: [Enricher, Bloater],
      consumers: [Consumer]
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
