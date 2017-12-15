defmodule ES.Commit do
  @derive [ExAws.Dynamo.Encodable]
  @type t :: module

  alias ES.{Commit}

  defstruct [
    stream_type:    nil,
    stream_uuid:    nil,
    stream_version: 0,
    timestamp:      0,
    events:         [],
    count:          0
  ]

  defmodule EventRecord do
    @derive [ExAws.Dynamo.Encodable]

    defstruct [
      sequence: 0,
      type:     nil,
      data:     nil,
    ]

    def new(sequence, event) do
      %__MODULE__{sequence: sequence, type: event_type(event), data: event}
    end

    defp event_type(event) when is_atom(event) do
      Atom.to_string(event)
    end

    defp event_type(s) do
      Atom.to_string(s.__struct__)
    end
  end

  def build(%{__struct__: module} = aggregate, expected_version, events) do
    new_commit = %Commit{
      stream_type:    module.stream_type(aggregate),
      stream_uuid:    module.stream_uuid(aggregate),
      stream_version: expected_version,
      timestamp:      ES.timestamp,
    }

    events
    |> List.wrap()
    |> Enum.reduce(new_commit, fn(event, %Commit{count: count, events: events} = record) ->
      next_count = count + 1
      new_event = EventRecord.new(next_count, event)
      %Commit{record | events: events ++ [new_event], count: next_count}
    end)
  end
end

