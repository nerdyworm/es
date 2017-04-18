defmodule ES.Storage.Ecto.EventSchema do
  use Ecto.Schema

  import Ecto.Changeset
  #import Ecto.Query

  schema "events" do
    field :stream_type, :string
    field :stream_uuid, :string
    field :stream_version, :integer
    field :events, :binary
    field :timestamp, :integer
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:stream_uuid, :stream_type, :stream_version, :events, :timestamp])
    |> validate_required([:stream_uuid, :stream_type, :stream_version, :events, :timestamp])
    |> unique_constraint(:version_conflict, name: :events_stream_uuid_stream_version_index)
  end
end


