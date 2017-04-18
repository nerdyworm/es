defmodule ES.Storage.Dynamodb do
  require Logger
  use GenServer

  alias ExAws.{Dynamo}
  alias ES.{Commit, Event}
  import ES.{Util, Storage}

  def start_link(store) do
    GenServer.start_link(__MODULE__, store, name: store)
  end

  def init(store) do
    {:ok, store}
  end

  def setup(store, options) do
    :ok = ES.Storage.Dynamodb.Setup.setup(store, options)
  end

  def get_event_by_id(store, event_id) do
    [stream_uuid, stream_version, sequence] =
      String.split(event_id, ".")

    results = read_events(store, stream_uuid, [
      return_consumed_capacity: "TOTAL",
      expression_attribute_values: [
        stream_uuid:    stream_uuid,
        stream_version: stream_version |> String.to_integer,
      ],
      consistent_read: false,
      key_condition_expression: "stream_uuid = :stream_uuid AND stream_version = :stream_version",
      scan_index_forward: false,
      limit: 1,
    ])

    case results do
      {:ok, []} ->
        nil

      {:ok, events} ->
        sequence = sequence |> String.to_integer
        Enum.find(events, &(&1.event_sequence == sequence))
    end
  end

  def commit(store, commit, attempts \\ 0) do
    table = store.config(:table)
    start = :os.system_time(:milli_seconds)
    packed = commit |> pack()

    opts = [
      condition_expression: "attribute_not_exists(stream_version)",
      return_consumed_capacity: "TOTAL",
    ]

    case Dynamo.put_item(table, packed, opts) |> ExAws.request do
      {:ok, results} ->
        consumed = results["ConsumedCapacity"]["CapacityUnits"]
        Logger.info "[write] stream_uuid=#{commit.stream_uuid} stream_version=#{commit.stream_version} size=#{human_filesize(packed)} events=#{commit.count} consumed=#{consumed} runtime=#{:os.system_time(:milli_seconds) - start}ms"
        {:ok, packed |> unpack()}

      {:error, {"ConditionalCheckFailedException", _}} ->
        {:error, :version_conflict}

      {:error, {"ProvisionedThroughputExceededException", _}} ->
        Logger.error "[write] [ProvisionedThroughputExceededException] stream_uuid=#{commit.stream_uuid} attempts=#{attempts}"
        :ok = enforce_limit!(store, commit, attempts)
        commit(store, commit, attempts + 1)

      {:error, why} ->
        {:error, why}
    end
  end

  defp enforce_limit!(store, commit, attempts) do
    max = store.config()[:max_commit_retries] || 5
    if attempts > max do
      raise ES.AppendRetryLimitReachedError, message: "stream_uuid=#{commit.stream_uuid} max=#{max}"
    else
      :ok = backoff(attempts)
    end
  end

  def read_stream_forward(store, stream_uuid, start_version, limit) when is_binary(start_version) do
    [_, stream_version, _] =
      String.split(start_version, ".")

    read_stream_forward(store, stream_uuid, stream_version, limit)
  end

  def read_stream_forward(store, stream_uuid, start_version, limit) do
    store
    |> read_events(stream_uuid, [
      return_consumed_capacity: "TOTAL",
      expression_attribute_values: [
        stream_uuid: stream_uuid,
        stream_version: start_version,
      ],
      key_condition_expression: "stream_uuid = :stream_uuid and stream_version > :stream_version",
      limit: limit,
    ])
    |> read_all_events(store, stream_uuid, limit, [])
  end

  defp read_all_events({:ok, incoming}, _store, _stream_uuid, _limit, events) do
    {:ok, events ++ incoming}
  end

  defp read_all_events({:ok, incoming, last_key}, store, stream_uuid, limit, events) do
    all = events ++ incoming
    if length(all) >= limit do
      {:ok, all}
    else
      store
      |> read_stream_forward(stream_uuid, last_key, limit)
      |> read_all_events(store, stream_uuid, limit, all)
    end
  end

  def read_stream_backward(store, stream_uuid, -1, limit) do
    results = read_events(store, stream_uuid, [
      return_consumed_capacity: "TOTAL",
      expression_attribute_values: [
        stream_uuid: stream_uuid,
      ],
      key_condition_expression: "stream_uuid = :stream_uuid",
      scan_index_forward: false,
      limit: limit,
    ])

    case results do
      {:ok, events} ->        {:ok, events |> Event.sort_backwards}
      {:ok, events, _last} -> {:ok, events |> Event.sort_backwards}
    end
  end

  def read_stream_backward(store, stream_uuid, start_version, limit) do
    results = read_events(store, stream_uuid, [
      return_consumed_capacity: "TOTAL",
      expression_attribute_values: [
        stream_uuid: stream_uuid,
        stream_version: start_version,
      ],
      key_condition_expression: "stream_uuid = :stream_uuid and stream_version < :stream_version",
      scan_index_forward: false,
      limit: limit,
    ])

    case results do
      {:ok, events} -> {:ok, events}
      {:ok, events, _last} -> {:ok, events}
    end
  end

  defp read_events(store, stream_uuid, query, attempts \\ 0) do
    table = store.config(:table)
    start = :os.system_time(:milli_seconds)

    case Dynamo.query(table, query) |> ExAws.request do
      {:ok, results} ->
        handle_results(stream_uuid, results, start)

      {:error, {"ProvisionedThroughputExceededException", _}} ->
        Logger.error "[read] [ProvisionedThroughputExceededException] stream_uuid=#{stream_uuid} attempts=#{attempts}"
        :ok = enforce_limit!(store, %{stream_uuid: stream_uuid}, attempts)
        read_events(store, stream_uuid, query, attempts + 1)
    end
  end

  defp handle_results(stream_uuid, results, start) do
    last_key = results["LastEvaluatedKey"]
    consumed = results["ConsumedCapacity"]["CapacityUnits"]
    count = results["Count"]
    if last_key do
      last_version = last_key["stream_version"]["N"] |> String.to_integer
      Logger.info "[read] stream_uuid=#{stream_uuid} consumed=#{consumed}u count=#{count} upto=#{last_version} duration=#{:os.system_time(:milli_seconds) - start}ms"
    else
      Logger.info "[read] stream_uuid=#{stream_uuid} consumed=#{consumed}u count=#{count} duration=#{:os.system_time(:milli_seconds) - start}ms"
    end

    events =
      Enum.map(results["Items"], fn(item) ->
        Dynamo.Decoder.decode(item, as: Commit)
        |> unpack()
      end)
      |> List.flatten

    case last_key do
      nil ->
        {:ok, events}

      key ->
        {:ok, events, key["stream_version"]["N"] |> String.to_integer}
    end
  end

  def decode_stream_record(%{"dynamodb" => %{"NewImage" => image}}) do
    ExAws.Dynamo.Decoder.decode(image, as: ES.Commit)
    |> unpack()
  end

  def transactional?() do
    false
  end

  def publish(aggregate, events) do
    {:ok, aggregate, events}
  end

  def after_commit(aggregate, events) do
    {:ok, aggregate, events}
  end
end
