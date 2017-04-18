defmodule ES.Storage.Memory do
  @behaviour ES.Storage.Adapter
  import ES.Storage

  use GenServer

  def start_link(store) do
    GenServer.start_link(__MODULE__, store, name: store)
  end

  def init(store) do
    items = :ets.new(Module.concat(store, Table), [:named_table, :set])
    {:ok, {store, items}}
  end

  def read_stream_forward(store, stream_uuid, start, limit) do
    GenServer.call(store, {:read_stream_forward, stream_uuid, start, limit})
  end

  def read_stream_backward(store, stream_uuid, start, limit) do
    GenServer.call(store, {:read_stream_backward, stream_uuid, start, limit})
  end

  def read_all_stream_forward(_store, _last_id, _limit) do
    {:ok, []}
  end

  def get_event_by_id(store, event_id) do
    [stream_uuid, stream_version, sequence] =
      String.split(event_id, ".")

    stream_version = stream_version |> String.to_integer
    sequence = sequence |> String.to_integer
    {:ok, events} = read_stream_forward(store, stream_uuid, stream_version - 1, sequence)
    Enum.find(events, &(&1.event_sequence == sequence))
  end

  def publish(store, aggregate, events) do
    store.streams()
    |> Enum.each(&(&1.notify(events, aggregate)))
    :ok
  end

  def commit(store, %ES.Commit{} = commit) do
    GenServer.call(store, {:commit, commit})
  end

  def handle_call({:commit, commit}, _, {_stream, items} = state) do
    {current, existing} = get(items, commit.stream_uuid)

    result =
      if commit.stream_version != current + 1 do
        {:error, :version_conflict}
      else
        events =
          commit
          |> pack()
          |> unpack()
          |> List.flatten
          |> Enum.reduce(existing, &([&1|&2]))

        :ets.insert(items, {commit.stream_uuid, commit.stream_version, events})
        {:ok, events}
      end

    {:reply, result, state}
  end

  def handle_call({:read_stream_forward, stream_uuid, start, limit}, from, state) when is_binary(start) do
    [_, stream_version, _] = String.split(start, ".")
    stream_version = stream_version |> String.to_integer
    handle_call({:read_stream_forward, stream_uuid, stream_version, limit}, from, state)
  end

  def handle_call({:read_stream_forward, stream_uuid, start, limit}, _, {_store, items} = state) do
    {_current, events} = get(items, stream_uuid)

    events =
      events
      |> Enum.reverse()
      |> Enum.filter(fn(event) ->
        event.stream_version > start
      end)
      |> Enum.take(limit)

    {:reply, {:ok, events}, state}
  end

  def handle_call({:read_stream_backward, stream_uuid, start, limit}, _, {_store, items} = state) do
    {_current, events} = get(items, stream_uuid)

    events =
      events
      |> Enum.filter(fn(event) ->
        if start == -1 do
          true
        else
          event.stream_version < start
        end
      end)
      |> Enum.take(limit)


    {:reply, {:ok, events}, state}
  end

  defp get(table, stream_uuid) do
    case :ets.lookup(table, stream_uuid) do
      [{^stream_uuid, version, commits}] -> {version, commits}
      [] -> {0, []}
    end
  end

  def setup(_store, _options), do: :ok
end
