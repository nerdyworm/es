defmodule ES.Stages.Ecto.Leaser do
  use GenServer
  require Logger

  alias ES.Stages.Ecto.Lease

  defstruct [
    :stream,
    :worker_id,
    :lease
  ]

  def start_link(stream, options) do
    GenServer.start_link(__MODULE__, {stream, options},
      name: Module.concat(stream, Leaser))
  end

  def init({stream, options}) do
    send(self(), :wake)
    {:ok, %__MODULE__{stream: stream, worker_id: options[:worker_id]}}
  end

  def handle_info(:wake, %{stream: stream, worker_id: worker_id} = state) do
    {:ok, lease} = Lease.take(worker_id, stream |> Atom.to_string)

    :ok = GenServer.call(stream, {:set_position, lease.checkpoint})

    state = %{state | lease: lease}
    {:noreply, state}
  end

  def handle_call({:checkpoint, %ES.Event{event_id: event_id}}, from, state) do
    handle_call({:checkpoint, event_id}, from, state)
  end

  def handle_call({:checkpoint, event_id}, _from, %{lease: %Lease{checkpoint: checkpoint}} = state) when event_id < checkpoint do
    Logger.info "checkpointed event_id=#{event_id}"
    {:reply, :ok, state}
  end

  def handle_call({:checkpoint, event_id}, _from, %{lease: lease} = state) when is_number(event_id) do
    Logger.info "checkpointed event_id=#{inspect event_id}"

    {:ok, lease} = Lease.checkpoint(lease, event_id)
    state = %{state | lease: lease}
    {:reply, :ok, state}
  end

  def handle_call({:checkpoint, event_id}, from, state) when is_binary(event_id) do
    repo = state.stream.repo()

    [stream_uuid, stream_version, _sequence] =
      String.split(event_id, ".")

    case repo.get_by(ES.Storage.Ecto.EventSchema, stream_uuid: stream_uuid, stream_version: stream_version) do
      nil ->
        Logger.warn "checkpointed event_id=#{inspect event_id} invalid checkpoint"
        {:reply, :ok, state}
      event ->
        handle_call({:checkpoint, event.id}, from, state)
    end
  end

  def handle_call({:checkpoint, _event_id}, _from, state) do
    {:reply, :ok, state}
  end
end
