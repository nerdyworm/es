defmodule ES.Storage do
  alias ES.{Event, Encoder, Commit}
  alias Commit.EventRecord

  def pack(%Commit{events: events} = commit) do
    %Commit{commit | events: events |> pack()}
  end

  def pack(events) when is_list(events) do
    Enum.map(events, &pack/1)
  end

  def pack(%EventRecord{data: data} = event) do
    %EventRecord{event | data: Encoder.encode(data)}
  end

  def unpack(%Commit{events: events} = commit) do
    Enum.map(events, fn(event) ->
      unpack(event, commit)
    end)
  end

  def unpack(%{"sequence" => sequence, "data" => event_data, "type" => event_type}, commit) do
    unpack(%{sequence: sequence, data: event_data, type: event_type}, commit)
  end

  def unpack(%{sequence: sequence, data: event_data, type: event_type}, commit) do
    event_type = event_type |> String.to_existing_atom
    %Event{
      event_id: "#{commit.stream_uuid}.#{commit.stream_version}.#{sequence}",
      event_data: Encoder.decode(event_data, as: event_type),
      event_type: event_type,
      event_sequence: sequence,
      stream_uuid: commit.stream_uuid,
      stream_version: commit.stream_version,
      stream_type: commit.stream_type |> String.to_existing_atom,
      timestamp: commit.timestamp,
    }
  end
end
