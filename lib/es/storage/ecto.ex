defmodule ES.Storage.Ecto do
  @behaviour ES.Storage.Adapter

  import Ecto.Query

  alias ES.{Commit, Encoder, Event, Storage}

  alias Storage.Ecto.{EventSchema}

  def start_link(store) do
    GenServer.start_link(__MODULE__, store, name: store)
  end

  def init(store) do
    {:ok, store}
  end

  def get_event_by_id(store, event_id) do
    [stream_uuid, stream_version, sequence] =
      String.split(event_id, ".")

    case store.repo().get_by(EventSchema, stream_uuid: stream_uuid, stream_version: stream_version) do
      nil ->
        nil

      event ->
        sequence = sequence |> String.to_integer
        events = event |> unpack()
        Enum.find(events, &(&1.event_sequence == sequence))
    end
  end

  def commit(store, %Commit{} = commit) do
    event = commit
            |> pack()
            |> EventSchema.changeset(%{})

    case store.repo.insert(event) do
      {:ok, event} ->
        {:ok, event |> unpack()}

      {:error, %Ecto.Changeset{errors: [version_conflict: {"has already been taken", []}]}} ->
        {:error, :version_conflict}
    end
  end

  defp pack(%Commit{events: events} = commit) do
    %EventSchema{
      stream_uuid:    commit.stream_uuid,
      stream_type:    commit.stream_type,
      stream_version: commit.stream_version,
      events:         events |> Encoder.encode,
      timestamp:      ES.timestamp
    }
  end

  def unpack(%EventSchema{events: events} = commit) do
    Encoder.decode(events)
    |> Enum.map(&(Storage.unpack(&1, commit)))
  end

  def read_all_stream_forward(store, last_id, limit \\ 1000) do
    results = store.repo().all(
        from e in EventSchema,
         where: e.id > ^last_id,
         limit: ^limit)

    events = Enum.map(results, &(unpack/1)) |> List.flatten

    {:ok, events}
  end

  def read_stream_forward(store, stream_uuid, start_version, limit) do
    results =
      store.repo().all(
        from e in EventSchema,
         where: e.stream_uuid == ^stream_uuid,
         where: e.stream_version > ^start_version,
         limit: ^limit)

    events = Enum.map(results, &(unpack/1)) |> List.flatten

    {:ok, events}
  end

  def read_stream_backward(store, stream_uuid, start_version, limit) do
    start_version =
      if start_version == -1 do
        1_000_000_000
      else
        start_version
      end

    results =
      store.repo().all(
        from e in EventSchema,
         where: e.stream_uuid == ^stream_uuid,
         where: e.stream_version < ^start_version,
         order_by: [asc: e.id],
         limit: ^limit)

    events =
      Enum.map(results, &(unpack/1))
      |> List.flatten
      |> Event.sort_backwards

    {:ok, events}
  end

  def setup(_store, _options) do
    :nack
  end
end
