defmodule ES.Storage.Dynamodb.Setup do
  require Logger
  use GenServer

  alias ExAws.{Dynamo}

  def setup(store, options) do
    table_name = store.config()[:table]

    results =
      table_name
      |> Dynamo.describe_table()
      |> ExAws.request()

    case results do
      {:ok, %{"Table" => %{"TableStatus" => "ACTIVE"}}} ->
        :ok

      {:ok, %{"Table" => %{"TableStatus" => "CREATING"}}} ->
        :timer.sleep(5000)
        setup(store, options)

      {:error, _} ->
        Logger.info "Creating #{table_name}"
        table_name
        |> Dynamo.create_table(
          [stream_uuid: :hash,   stream_version: :range],
          [stream_uuid: :string, stream_version: :number], 1, 1)
        |> ExAws.request!()

        setup(store, options)
    end
  end
end
