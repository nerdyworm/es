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
end

