defmodule ES.EventStore do
  @type t :: module

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      import ES.{EventStore, Util}
      require Logger

      {otp_app, adapter, dispatcher, config} = parse_config(opts)
      @otp_app otp_app
      @adapter adapter
      @config config
      @dispatcher dispatcher

      def start_link do
        @adapter.start_link(__MODULE__)
      end

      def config(),  do: @config
      def config(name), do: Keyword.get(@config, name)

      def adapter(), do: @adapter
      def repo(),    do: @config[:repo]

      def setup(options \\ []) do
        @adapter.setup(__MODULE__, options)
      end

      def append_to_stream(%{version: version} = aggregate, events) do
        append_to_stream(aggregate, events, version)
      end

      def append_to_stream(aggregate, events, expected_version) do
        commit = ES.Commit.build(aggregate, expected_version, events)
        case @adapter.commit(__MODULE__, commit) do
          {:error, reason} ->
            {:error, reason}

          {:ok, events} ->
            :ok = notify_streams(events)
            {:ok, events}
        end
      end

      def read_stream_forward(aggregate, start \\ -1, limit \\ 100)
      def read_stream_forward(%{__struct__: module} = aggregate, start, limit) do
        stream_uuid = module.stream_uuid(aggregate)
        read_stream_forward(stream_uuid, start, limit)
      end

      def read_stream_forward(stream_uuid, start, limit) do
        @adapter.read_stream_forward(__MODULE__, stream_uuid, start, limit)
      end

      def read_all_stream_forward(start, limit) do
        @adapter.read_all_stream_forward(__MODULE__, start, limit)
      end

      def read_stream_backward(aggregate, start \\ -1, limit \\ 100)
      def read_stream_backward(%{__struct__: module} = aggregate, start, limit) do
        stream_uuid = module.stream_uuid(aggregate)
        read_stream_backward(stream_uuid, start, limit)
      end

      def read_stream_backward(stream_uuid, start, limit) do
        @adapter.read_stream_backward(__MODULE__, stream_uuid, start, limit)
      end

      def refresh_from_stream(%{__struct__: stream_type, version: version} = aggregate, limit \\ 100) do
        case read_stream_forward(aggregate, version, limit) do
          {:ok, []} ->
            aggregate

          {:ok, events} ->
            aggregate = stream_type.replay(aggregate, events)
            if length(events) < limit do
              aggregate
            else
              refresh_from_stream(aggregate, limit)
            end
        end
      end

      def get(stream_type, stream_uuid) do
        if stream_type.__schema__(:source) do
          repo().get(stream_type, stream_uuid)
          |> stream_type.preload()
        else
          stream_uuid
          |> stream_type.new()
          |> refresh_from_stream()
        end
      end

      def cached(stream_type, stream_uuid) do
        case ES.Cache.read_cache(stream_uuid) do
          :notfound ->
            Logger.info "[cache] miss #{stream_uuid}"
            aggregate = get(stream_type, stream_uuid)
            :ok = ES.Cache.write_cache(stream_uuid, aggregate)
            aggregate

          {:ok, cached} ->
            cached
        end
      end

      def get(%ES.Event{
        stream_uuid: stream_uuid,
        stream_type: stream_type,
        stream_version: stream_version,
        event_data: event_data,
      } = event) do
        case ES.Cache.read_cache(stream_uuid) do
          :notfound ->
            Logger.info "[cache] miss #{stream_uuid}"
            aggregate = get(stream_type, stream_uuid)
            :ok = ES.Cache.write_cache(stream_uuid, aggregate)
            aggregate

          {:ok, cached} ->
            if cached.version < stream_version do
              events =
                if stream_version - cached.version == 1 do
                  [event]
                else
                  {:ok, events} = read_stream_forward(cached, cached.version, stream_version)
                  events
                end

              Logger.info fn() ->
                "[cache] #{stream_uuid} update cached_version=#{cached.version} stream_version=#{stream_version} events=#{length(events)}"
              end

              aggregate = stream_type.replay(cached, events)
              :ok = ES.Cache.write_cache(stream_uuid, aggregate)
              aggregate
            else
              cached
            end
        end
      end

      def get_event_by_id(event_id) do
        @adapter.get_event_by_id(__MODULE__, event_id)
      end

      def commit(aggregate) do
        case ES.Transaction.commit(__MODULE__, aggregate) do
          {:error, :version_conflict} ->
            {:error, :version_conflict}

          {:ok, aggregate, _events} ->
            {:ok, aggregate}
        end
      end

      def commit(%{__struct__: module} = aggregate, event) do
        case module.apply(aggregate, event) do
          {:error, changeset} -> {:errors, changeset}
          {:ok, aggregate} -> commit(aggregate)
        end
      end

      def commit(%{__struct__: module, version: version} = unchanged, event, :append, attempts \\ 0) do
        case module.apply(unchanged, event) do
          {:error, changeset} ->
            {:errors, changeset}

          {:ok, aggregate} ->
            case commit(aggregate) do
              {:ok, aggregate} -> {:ok, aggregate}

              {:error, :version_conflict} ->
                :ok = enforce_limit!(unchanged, attempts)

                unchanged
                |> refresh_from_stream()
                |> commit(event, :append, attempts + 1)
            end
        end
      end

      defp enforce_limit!(%{__struct__: module} = aggregate, attempts) do
        max = @config[:max_append_attempts] || 5
        if attempts > max do
          stream_uuid = module.stream_uuid(aggregate)
          raise ES.AppendRetryLimitReachedError, message: "stream_uuid=#{stream_uuid} max=#{max}"
        else
          :ok = backoff(attempts)
        end
      end

      defp notify_streams(events) do
        @dispatcher.dispatch(__MODULE__, events)
      end

      def streams() do
        @otp_app
        |> Application.get_env(__MODULE__,  [])
        |> Keyword.get(:streams, @config[:streams] || [])
      end

      def add_stream(stream) do
        config = Application.get_env(@otp_app, __MODULE__, [])

        streams = Keyword.get(config, :streams, [])
        streams = [stream|streams] |> Enum.uniq

        config = Keyword.put(config, :streams, streams)
        Application.put_env(@otp_app, __MODULE__, config)
      end
    end
  end

  alias ES.Dispatcher.{Inline, NOOP}

  def parse_config(config) do
    otp_app = config[:otp_app]
    adapter = config[:adapter]
    dispatcher = if config[:inline], do: Inline, else: NOOP
    {otp_app, adapter, dispatcher, config}
  end
end
