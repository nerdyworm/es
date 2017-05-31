defmodule ES.Storage.DynamodbAdapterTest do
  use ES.StorageAdapterCase

  defmodule Store do
    use ES.EventStore, adapter: ES.Storage.Dynamodb,
      inline: true, table: "SubZero.Events", repo: ES.Repo
  end

  setup_all do
    {:ok, pid} = Store.start_link
    on_exit(fn ->
      ref = Process.monitor(pid)
      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      end
    end)

    :ok
  end

  setup do
    Process.register(self(), :testing)
    {:ok, store: Store}
  end

  @limit 500
  def stream(store)  do
    store.all(@limit)
    |> handle_response(store)
  end

  def stream(store, last) do
    last
    |> store.all(@limit)
    |> handle_response(store)
  end

  defp handle_response({:ok, events}, _store) do
    process_events(events)
  end

  defp handle_response({:ok, events, last}, store) do
    process_events(events)
    stream(store, last)
  end

  def process_events(events) do
    Enum.each(events, fn(event) ->
      IO.inspect event
    end)
    IO.puts "consumed: #{length(events)}"
  end

  @tag timeout: 20 * 60 * 1000
  test "forward", %{store: store} do
    stream(store)
  end
end

