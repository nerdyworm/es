defmodule ES.Stages.Ecto do
  require Logger
  import Supervisor.Spec

  def start_link(stream, options) do
    options = Keyword.put(options, :worker_id, ES.uuid)

    children = [
      worker(ES.Stages.Ecto.Leaser, [stream, options]),
      worker(ES.Stages.Ecto.Producer, [stream, options]),
    ]

    enrichers = ES.Stages.enrichers(stream, options)
    consumers = ES.Stages.consumers(stream, options)
    children = children ++ enrichers ++ consumers

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  # not an inline adapter, should not notify
  # from event store
  def notify(_stream, _store, _events), do: :ok

  def notify(stream, events) do
    :ok = GenStage.call(stream, {:notify, events})
  end

  def checkpoint(stream, checkpoint) do
    :ok = GenStage.call(Module.concat(stream, Leaser), {:checkpoint, checkpoint})
  end

  def nack(stream, event, message) do
    Logger.error "#{stream} nacking event_id=#{event.event_id}"
    stream.repo().insert!(
      %ES.Storage.Ecto.EventError{
        event_id: "#{event.event_id}",
        message: message,
        worker: "TODO - grab from stream options or something",
        handler: "hmmm, can't just have one",
      }
    )
    :ok
  end
end
