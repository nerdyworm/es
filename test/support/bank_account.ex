defmodule BankAccount.Opened do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :uuid, :string
    field :name, :string
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:uuid, :name])
    |> Ecto.Changeset.validate_required([:uuid, :name])
  end
end

defmodule BankAccount.Widthdrawled do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :amount, :string
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:amount])
    |> Ecto.Changeset.validate_required(:amount)
  end
end

defmodule BankAccount.Rejected do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :amount, :string
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:amount])
    |> Ecto.Changeset.validate_required(:amount)
  end
end

defmodule BankAccount.Deposited do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :amount, :string
  end

  def changeset(struct, params \\ %{}) do struct
    |> Ecto.Changeset.cast(params, [:amount])
    |> Ecto.Changeset.validate_required(:amount)
  end
end

defmodule BankAccount do
  use ES.Aggregate
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "bank_accounts" do
    field :name, :string
    field :balance, :integer, default: 0
    field :version, :integer, default: 0 # required
    field :pending, {:array, :string}, default: [], virtual: true #  required
    field :changesets, {:array, :string}, default: [], virtual: true #  required
    timestamps()
  end

  def open(name) do
    %BankAccount{}
    |> apply(%BankAccount.Opened{uuid: ES.uuid, name: name})
  end

  def deposit(account, amount) do
    account
    |> apply(%BankAccount.Deposited{amount: amount})
  end

  def widthdraw(account, amount) do
    if account.balance - amount < 0 do
      account
      |> apply(%BankAccount.Rejected{amount: amount})
    else
      account
      |> apply(%BankAccount.Widthdrawled{amount: amount})
    end
  end

  def handle_event(%BankAccount.Opened{uuid: uuid, name: name}, account) do
    account
    |> change(%{id: uuid, name: name, balance: 0})
  end

  def handle_event(%BankAccount.Deposited{amount: amount}, account) do
    account
    |> change(%{balance: account.balance + amount})
  end

  def handle_event(%BankAccount.Widthdrawled{amount: amount}, account) do
    account
    |> change(%{balance: account.balance - amount})
  end

  def handle_event(%BankAccount.Rejected{}, account) do
    account
  end
end
