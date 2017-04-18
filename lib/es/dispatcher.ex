defmodule ES.Dispatcher do
  defmodule NOOP do
    def dispatch(_store, _events) do
      :ok
    end
  end

  defmodule Inline do
    def dispatch(store, events) do
      streams = store.streams()
      Enum.each(streams, fn(stream) ->
        Enum.each(stream.consumers(), fn(handler) ->
          :erlang.apply(handler, :handle_events, [events, nil, stream])
        end)
      end)
    end
  end
end
