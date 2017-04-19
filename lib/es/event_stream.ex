defmodule ES.EventStream do
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @options opts
      @adapter opts[:adapter]

      def store(), do: @options[:store]
      def repo(),  do: @options[:repo]

      def config(name) do
        Keyword.get(@options, name)
      end

      def enrichers() do
        Keyword.get(@options, :enrichers, [])
      end

      def consumers() do
        Keyword.get(@options, :consumers, [])
      end

      def start_link do
        @adapter.start_link(__MODULE__, @options)
      end

      def notify(event) do
        @adapter.notify(__MODULE__, event)
      end

      def notify(store, event) do
        @adapter.notify(__MODULE__, store, event)
      end

      def checkpoint(checkpoint) do
        @adapter.checkpoint(__MODULE__, checkpoint)
      end

      def nack(event_ids, reason) do
        @adapter.nack(__MODULE__, event_ids, reason)
      end

      def setup(options \\ []) do
        @adapter.setup(__MODULE__, options)
      end

      defoverridable [consumers: 0]
    end
  end
end
