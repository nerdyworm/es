defmodule ES.Stages.Inline do
  require Logger

  use GenServer

  defstruct [:stream, :options]

  def start_link(stream, options) do
    GenServer.start_link(__MODULE__, {stream, options}, name: stream)
  end

  def init({stream, options}) do
    {:ok, %__MODULE__{stream: stream, options: options}}
  end

  def notify(stream, events) do
    events = List.wrap(events)
    enrichers = stream.enrichers()
    consumers = stream.consumers()

    enriched =
      if length(enrichers) > 0 do
        Enum.reduce(enrichers, events, fn(enricher, acc) ->
          case enricher.handle_events(acc, nil, stream) do
            {:noreply, events, _stream} -> events
          end
        end)
      else
        events
      end

    Enum.each(consumers, fn(consumer) ->
      consumer.handle_events(enriched, self(), stream)
    end)
  end

  def checkpoint(_stream, _event) do
    :ok
  end

  def nack(stream, event, message) do
    Logger.error("[#{stream}] #{inspect event.event_data} \n\n #{message}")
    :ok
  end
end
