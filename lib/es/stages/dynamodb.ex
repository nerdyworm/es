defmodule ES.Stages.Dynamodb do
  import Supervisor.Spec

  alias ExKcl.{
    Stream,
    Adapters.Dynamodb
  }

  def start_link(stream, options) do
    config = Keyword.merge(
      Stream.default_config,
      options
    )

    config = Keyword.merge(config,
     adapter: Dynamodb,
     stream: stream,
    )

    children = [
      worker(ES.Stages.Dynamodb.Producer, [stream, options]),
      supervisor(ExKcl, [__MODULE__, config]),
    ]

    enrichers = ES.Stages.enrichers(stream, options)
    consumers = ES.Stages.consumers(stream, options)
    children = children ++ enrichers ++ consumers

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  # should each shard should be it's own pipeline?
  def handle_records(records, options) do
    stream = options[:stream]
    events =
      Enum.flat_map(records, fn(record) ->
        decode_stream_record(record)
      end)

    :ok = GenStage.call(stream, {:notify, events}, 30_000)
  end

  def decode_stream_record(record) do
    ES.Storage.Dynamodb.decode_stream_record(record)
  end

  def checkpoint(_stream, _event) do
    :ok
  end

  # not an inline adapter, should not notify
  # from event store
  def notify(_stream, _store, _events), do: :ok

  def notify(stream, events) do
    :ok = GenStage.call(stream, {:notify, events})
  end

  def setup(stream, _options) do
    table = stream.config(:lease_table_name)
    :ok = ExKcl.Util.setup_lease_table(table)
  end
end
