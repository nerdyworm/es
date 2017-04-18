defmodule Workflow.Started do
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

defmodule Workflow.Completed do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :at, Ecto.DateTime
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:at])
    |> Ecto.Changeset.validate_required([:at])
  end
end

defmodule Workflow do
  use ES.Aggregate
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :version, :integer, default: 0 # required
    field :pending, {:array, :string}, default: [], virtual: true
    field :changesets, {:array, :string}, default: [], virtual: true
  end

  def start(uuid, name) do
    %Workflow{}
    |> apply(%Workflow.Started{name: name, uuid: uuid})
  end

  def complete(workflow) do
    workflow
    |> apply(%Workflow.Completed{at: Ecto.DateTime.utc()})
  end

  def handle_event(%Workflow.Started{name: name, uuid: uuid}, workflow) do
    workflow
    |> change(%{name: name, id: uuid})
  end

  def handle_event(%Workflow.Completed{}, workflow) do
    workflow
  end

  require Logger
  def handle_event(event, workflow) do
    Logger.debug "unknown event: #{inspect event}"
    workflow
  end
end
