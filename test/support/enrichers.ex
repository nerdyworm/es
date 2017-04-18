defmodule Bloater do
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
    events = Enum.map(events, &({:bloated, &1}))
    {:noreply, events, stream}
  end
end
