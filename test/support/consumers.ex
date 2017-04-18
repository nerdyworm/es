defmodule Consumer do
  use ES.EventConsumer

  def handle_event(event) do
    Logger.debug "[Consumer] consumer: #{inspect event}"
    send(:testing, event)
    :ok
  end
end

defmodule BadConsumer do
  use ES.EventConsumer

  def handle_event(event) do
    #IO.puts "event: #{inspect event.event_id}"
    if event.event_id == 1 do
      raise "BadConsumer event_id=#{event.event_id}"
    end

    send(:testing, event)
    :ok
  end
end

