defmodule ES.Storage.Ecto.EventError do
  use Ecto.Schema

  #import Ecto
  #import Ecto.Changeset
  #import Ecto.Query

  schema "event_errors" do
    field :event_id, :string
    field :message, :string
    field :handler, :string
    field :worker, :string
    timestamps()
  end
end

