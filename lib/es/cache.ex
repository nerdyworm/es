defmodule ES.Cache do
  require Logger
  use GenServer

  defmodule State do
    defstruct store: nil, cache: nil
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    cache = :ets.new(:es_cache, [:named_table, :set])
    Process.send_after(self(), :gc, 1000)
    {:ok, %State{cache: cache}}
  end

  def handle_info(:gc, %State{cache: cache} = state) do
    match_spec = [
      {{:"$1", :"$2", :"$3"}, [{:<, :"$3", ES.timestamp}], [:"$1"]}
    ]

    cache
    |> :ets.select(match_spec)
    |> Enum.each(fn(stream_uuid) ->
      true = :ets.delete(state.cache, stream_uuid)
      Logger.debug fn -> "[cache] expiring #{stream_uuid}" end
    end)

    Process.send_after(self(), :gc, 1000)
    {:noreply, state}
  end

  def read_cache(stream_uuid) do
    GenServer.call(__MODULE__, {:read_cache, stream_uuid})
  end

  def write_cache(stream_uuid, aggregate) do
    GenServer.call(__MODULE__, {:write_cache, stream_uuid, aggregate})
  end

  def handle_call({:read_cache, stream_uuid}, _from, state) do
    result =
      case :ets.lookup(state.cache, stream_uuid) do
        [] -> :notfound
        [{^stream_uuid, result, _ttl}] ->
          true = :ets.insert(state.cache, {stream_uuid, result, ttl()})
          {:ok, result}
      end

    {:reply, result, state}
  end

  def handle_call({:write_cache, stream_uuid, aggregate}, _from, state) do
    true = :ets.insert(state.cache, {stream_uuid, aggregate, ttl()})
    {:reply, :ok, state}
  end

  def ttl do
    ES.timestamp + Application.get_env(:es, :cache_ttl, 60 * 5)
  end
end

