defmodule Person do
  use ES.Aggregate
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :version, :integer, default: 0
    field :pending, {:array, :string}, default: [], virtual: true
    field :changesets, {:array, :string}, default: [], virtual: true
  end

  defmodule Created do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :name, :string
      field :uuid, :string
    end

    def changeset(struct, params \\ %{}) do
      struct
      |> Ecto.Changeset.cast(params, [:name, :uuid])
      |> Ecto.Changeset.validate_required([:name, :uuid])
    end
  end

  def create(uuid, name) do
    %Person{}
    |> apply(%Created{name: name, uuid: uuid})
  end

  def handle_event(%Created{name: name, uuid: uuid}, workflow) do
    workflow
    |> change(%{name: name, id: uuid})
  end
end
