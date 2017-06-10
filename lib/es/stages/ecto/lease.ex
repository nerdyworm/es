defmodule ES.Stages.Ecto.Lease do
  use Ecto.Schema

  import Ecto.{Changeset, Query}
  alias ES.Stages.Ecto.Lease

  schema "leases" do
    field :owner, :string
    field :name, :string
    field :checkpoint, :integer
    field :counter, :integer
    field :status, :string, default: "ok"
    timestamps()
  end

  def take(owner, name) do
    query =
      from l in Lease,
        where: l.name == ^name,
        limit: 1

    case repo().one(query) do
      nil ->
        %Lease{owner: owner, name: name, checkpoint: -1, counter: 0}
        |> repo().insert

      lease ->
        lease
        |> Lease.changeset(%{owner: owner})
        |> repo().update
    end
  end

  def checkpoint(lease, last_id) do
    lease
    |> Lease.changeset(%{checkpoint: last_id})
    |> repo().update
  end

  def ack(lease, last_id) do
    lease
    |> Lease.changeset(%{checkpoint: last_id})
    |> repo().update
  end

  def resume(lease) do
    lease
    |> Lease.changeset(%{status: "ok"})
    |> repo().update
  end

  def pause(lease, last_id) do
    lease
    |> Lease.changeset(%{checkpoint: last_id, status: "paused"})
    |> repo().update
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:owner, :name, :counter, :checkpoint, :status])
    |> validate_required([:owner, :name, :counter, :checkpoint, :status])
  end

  defp repo do
    ES.Repo
  end
end
