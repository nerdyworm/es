defmodule ES.EventConsumer do
  defmacro __using__(opts) do
    #quote location: :keep, bind_quoted: [opts: opts] do
    quote bind_quoted: [opts: opts] do
      require Logger
      use GenStage

      def start_link(stream, options) do
        GenStage.start_link(__MODULE__, {stream, options}, name: Module.concat(stream, __MODULE__))
      end

      def init({stream, options}) do
        subscribe_to = Keyword.get(options, :subscribe_to)
        {:consumer, stream, subscribe_to: subscribe_to}
      end

      def handle_events(events, _from, stream) do
        Enum.each(events, fn(event) ->
          :ok = try_handle_event(event, stream)
        end)

        event = List.last(events)
        :ok = stream.checkpoint(event)

        {:noreply, [], stream}
      end

      defp try_handle_event(event, stream) do
        try do
          :ok = handle_event(event)
        catch
          kind, reason ->
            message = Exception.format(kind, reason, System.stacktrace)
            :ok = stream.nack(event, message)
        end
      end

      defoverridable [
        start_link: 2,
        init: 1,
        handle_events: 3,
      ]
    end
  end
end
