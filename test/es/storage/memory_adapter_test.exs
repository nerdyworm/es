defmodule ES.Storage.MemoryAdapterTest do
  use ES.StorageAdapterCase
  use ExUnit.Case

  defmodule Store do
    use ES.EventStore, adapter: ES.Storage.Memory, repo: ES.Repo
  end

  setup_all context do
    {:ok, pid} = Store.start_link
    on_exit(context, fn() ->
      Process.exit(pid, :exit)
    end)

    :ok
  end

  setup do
    Process.register(self(), :testing)
    {:ok, store: Store}
  end
end
