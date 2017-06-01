defmodule ES.EventStoreStream do
  def new(store, batch \\ 500) do
    Stream.resource(fn -> {store, :start, batch} end, &next/1, &finish/1)
  end

  defp next(:last) do
    {:halt, :ok}
  end

  defp next({store, :start, batch}) do
    case store.all(batch) do
      {:ok, events} ->
        {events, :last}

      {:ok, events, last} ->
        {events, {store, last, batch}}
    end
  end

  defp next({store, last, batch}) do
    case store.all(last, batch) do
      {:ok, events} ->
        {events, :last}

      {:ok, events, last} ->
        {events, {store, last, batch}}
    end
  end

  defp finish(:ok) do
    :ok
  end

  defp finish(last) do
    last
  end
end

