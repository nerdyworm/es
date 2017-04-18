defmodule ES.Stages.Dynamodb.Producer do
  use GenStage

  def start_link(stream, _options) do
    GenStage.start_link(__MODULE__, :ok, name: stream)
  end

  def notify(event, timeout \\ 5000) do
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  def init(:ok) do
    {:producer, {:queue.new, 0}, dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_call({:notify, events}, from, {queue, demand}) when is_list(events) do
    enqueue_events(events, from, {queue, demand})
  end

  def handle_call({:notify, event}, from, {queue, demand}) do
    dispatch_events(:queue.in({from, event}, queue), demand, [])
  end

  def handle_demand(incoming_demand, {queue, demand}) do
    dispatch_events(queue, incoming_demand + demand, [])
  end

  defp dispatch_events(queue, demand, events) do
    with d when d > 0 <- demand,
         {{:value, {from, event}}, queue} <- :queue.out(queue) do
      GenStage.reply(from, :ok)
      dispatch_events(queue, demand - 1, [event | events])
    else
      _ -> {:noreply, Enum.reverse(events), {queue, demand}}
    end
  end

  defp enqueue_events([], _from, {queue, demand}) do
    dispatch_events(queue, demand, [])
  end

  defp enqueue_events([event|events], from, {queue, demand}) do
    enqueue_events(events, from, {:queue.in({from, event}, queue), demand})
  end
end
