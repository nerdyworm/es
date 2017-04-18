defmodule ES.Stages.Ecto.Producer do
  use GenStage
  require Logger

  defstruct [stream: nil, demand: 0, position: nil, timer: nil, queue: nil]

  def start_link(stream, options) do
    GenStage.start_link(__MODULE__, {stream, options}, name: stream)
  end

  def init({stream, _options}) do
    state = %__MODULE__{stream: stream, queue: :queue.new}
    {:producer, state, [dispatcher: GenStage.BroadcastDispatcher]}
  end

  def handle_call({:notify, events}, from, state) when is_list(events) do
    enqueue_events(events, from, state)
  end

  def handle_call({:notify, event}, from, state) do
    enqueue_events([event], from, state)
  end

  def handle_call({:set_position, event_id}, from, state) do
    :ok = GenStage.reply(from, :ok)
    %{state | position: event_id}
    |> dispatch()
  end

  def handle_info(:dispatch, state) do
    state
    |> dispatch()
  end

  def handle_demand(incoming_demand, %{demand: demand} = state) do
    %{state | demand: incoming_demand + demand}
    |> dispatch()
  end

  def dispatch(%{position: position} = state) when is_nil(position) do
    {:noreply, [], state}
  end

  def dispatch(%{timer: timer} = state) when timer != nil do
    :erlang.cancel_timer(timer)

    %{state | timer: nil}
    |> dispatch()
  end

  def dispatch(%{demand: demand, position: position, timer: timer, stream: stream} = state) do
    {:ok, events} = stream.store().read_all_stream_forward(position, demand)

    new_events = length(events)
    demand = demand - new_events
    state = %{state | demand: demand}

    state =
      if demand > 0 || new_events == 0 do
        timer = Process.send_after(self(), :dispatch, 500)
        %{state | timer: timer}
      else
        state
      end

    state =
      if new_events > 0 do
        %{state | position: position + new_events}
      else
        state
      end

    enqueue_events(events, nil, state)
  end

  defp enqueue_events([], _from, state) do
    dispatch_events(state, [])
  end

  defp enqueue_events([event|events], from, %{queue: queue} = state) do
    state = %{state | queue: :queue.in({from, event}, queue)}
    enqueue_events(events, from, state)
  end

  defp dispatch_events(%{queue: queue, demand: demand} = state, events) do
    with d when d > 0 <- demand,
         {{:value, {from, event}}, queue} <- :queue.out(queue) do

      if from != nil, do: GenStage.reply(from, :ok)

      state = %{state | queue: queue, demand: demand - 1}
      dispatch_events(state, [event | events])
    else
      _ -> {:noreply, Enum.reverse(events), state}
    end
  end
end
