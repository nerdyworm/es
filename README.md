# ES

Event Sourcing for Ecto and Postgresl/Dynamodb events storage.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `es` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:es, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/es](https://hexdocs.pm/es).

## Configuration

### Aggregates

```elixir
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

defmodule EventStore do
  use ES.EventStore, adapter: ES.Storage.Memory, inline: true
end

{:ok, pid} = EventStore.start_link

{:ok, aggregate} = Person.create(ES.uuid, "bob")
{:ok, aggregate} = EventStore.commit(aggregate)
{aggregate.name, aggregate.version}
```
