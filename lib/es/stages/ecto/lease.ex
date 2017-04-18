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

    case ES.Repo.one(query) do
      nil ->
        %Lease{owner: owner, name: name, checkpoint: -1, counter: 0}
        |> ES.Repo.insert

      lease ->
        lease
        |> Lease.changeset(%{owner: owner})
        |> ES.Repo.update
    end
  end

  def checkpoint(lease, last_id) do
    lease
    |> Lease.changeset(%{checkpoint: last_id})
    |> ES.Repo.update
  end

  def ack(lease, last_id) do
    lease
    |> Lease.changeset(%{checkpoint: last_id})
    |> ES.Repo.update
  end

  def resume(lease) do
    lease
    |> Lease.changeset(%{status: "ok"})
    |> ES.Repo.update
  end

  def pause(lease, last_id) do
    lease
    |> Lease.changeset(%{checkpoint: last_id, status: "paused"})
    |> ES.Repo.update
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:owner, :name, :counter, :checkpoint, :status])
    |> validate_required([:owner, :name, :counter, :checkpoint, :status])
  end
end
