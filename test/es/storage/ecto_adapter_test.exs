defmodule ES.Storage.EctoAdapterTest do
  use ES.StorageAdapterCase

  defmodule Store do
    use ES.EventStore, adapter: ES.Storage.Ecto, repo: ES.Repo, inline: true
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

