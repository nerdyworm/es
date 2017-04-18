defmodule ES.Storage.Adapter do
  @type t :: module

  @typep store :: ES.EventStore.t
  @typep commit :: ES.Commit.t
  @typep event :: ES.Event.t
  @typep stream_uuid :: String.t
  @typep event_id :: String.t

  @callback start_link(store) :: {:ok, pid} | {:error, any}
  @callback read_stream_forward(store, stream_uuid, number, number) :: {:ok, list(event)} | {:error, any}
  @callback read_stream_backward(store, stream_uuid, number, number) :: {:ok, list(event)} | {:error, any}
  @callback commit(store, commit) :: {:ok, list(event)} | {:error, :conflict}
  @callback get_event_by_id(store, event_id) :: event | nil
end

