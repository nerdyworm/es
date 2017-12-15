defmodule ES.Event do
  @type t :: module

  defstruct [
    event_id:       nil,
    stream_type:    nil,
    stream_uuid:    nil,
    stream_version: 0,
    event_type:     nil,
    event_data:     nil,
    event_sequence: 0,
    timestamp:      0
  ]

  def new(stream_uuid, stream_version, event) do
    %__MODULE__{
      stream_uuid: stream_uuid,
      stream_version: stream_version,
      event_type: event_type(event),
      event_data: event,
      timestamp: ES.timestamp
    }
  end

  defp event_type(event) when is_atom(event) do
    Atom.to_string(event)
  end

  defp event_type(s) do
    Atom.to_string(s.__struct__)
  end

  def sort_backwards(events) do
    events
    |> Enum.sort_by(&(&1.event_sequence))
    |> Enum.sort_by(&(&1.stream_version))
    |> Enum.reverse()
  end
end

defimpl Poison.Decoder, for: ES.Event do
  alias Poison.Decode

  def decode(%{stream_type: stream_type, event_type: event_type, event_data: event_data} = event, _options) do
    event_type = event_type |> String.to_existing_atom
    %{event |
      stream_type: stream_type |> String.to_existing_atom,
      event_type: event_type,
      event_data: Decode.decode(event_data, as: struct(event_type))}
  end
end
