defmodule ES.Repo.Migrations.CreateTestSchema do
  use Ecto.Migration

  def change do
    create table(:bank_accounts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :balance, :integer, null: false, default: 0
      add :version, :integer, null: false
      timestamps()
    end

    create table(:events) do
      add :stream_type, :string, null: false
      add :stream_uuid, :string, null: false
      add :stream_version, :integer, null: false
      add :events, :binary, null: false
      add :timestamp, :integer, null: false
    end

    create index(:events, [:stream_uuid])
    create unique_index(:events, [:stream_uuid, :stream_version])

    create table(:leases) do
      add :owner, :string, null: true
      add :name, :string, null: false
      add :status, :string, null: false, default: "ok"
      add :checkpoint, :integer, null: false
      add :counter, :integer, null: false
      timestamps()
    end

    create unique_index(:leases, [:name])

    create table(:event_errors) do
      add :event_id, :text, null: true
      add :message, :text, null: false
      add :handler, :string, null: false
      add :worker, :string, null: false
      timestamps()
    end

    create table(:nacks) do
      add :event_id, :text, null: true
      add :stream, :string, null: false
      timestamps()
    end
  end
end
