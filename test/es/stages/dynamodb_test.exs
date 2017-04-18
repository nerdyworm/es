defmodule ES.Stages.DynamodbTest do
  use ES.Stages.Case

  defmodule Enricher do
    use GenStage

    def start_link(stream, options) do
      GenStage.start_link(__MODULE__, {stream, options},
        name: Module.concat(stream, __MODULE__))
    end

    def init({stream, options}) do
      subscribe_to = Keyword.get(options, :subscribe_to)
      {:producer_consumer, stream, [subscribe_to: subscribe_to, dispatcher: GenStage.BroadcastDispatcher]}
    end

    def handle_events(events, _from, stream) do
      events = Enum.map(events, &({:enriched, &1}))
      {:noreply, events, stream}
    end
  end

  defmodule Store do
    use ES.EventStore,
      adapter: ES.Storage.Dynamodb,
      repo: ES.Repo,
      table: "SubZero.Events"
  end

  defmodule Stage do
    use ES.EventStream,
      adapter: ES.Stages.Dynamodb,
      enrichers: [Enricher, Bloater],
      consumers: [Consumer],
      repo: ES.Repo,
      store: Store,
      stream_name: "arn:aws:dynamodb:us-east-1:907015576586:table/SubZero.Events/stream/2017-01-22T01:45:50.219",
      lease_table_name: "leases_test",
      lease_stale_after: 5000,
      coordinator_sync_interval:  1000,
      shard_syncer_sync_interval: 1000,
      shard_syncer_start_timeout: 0,
      idle_ms: 1000
  end

  defmodule App do
    def start do
      import Supervisor.Spec

      children = [
        worker(Store, []),
        worker(Stage, []),
      ]

      Supervisor.start_link(children, [
        strategy: :one_for_one,
        max_restarts: 100,
        max_seconds: 1
      ])
    end
  end

  setup_all context do
    {:ok, pid} = App.start

    :ok = Stage.setup

    on_exit(context, fn() ->
      ref = Process.monitor(pid)
      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      end
    end)
  end

  setup do
    Process.register(self(), :testing)
    {:ok, %{stage: Stage}}
  end

  def seed(events) do
    event = %BankAccount.Opened{uuid: ES.uuid, name: "bank account"}
    {:ok, bank_account} = Store.commit(%BankAccount{}, event)

    if events > 1 do
      Enum.reduce(1..events - 1, bank_account, fn(_, bank_account) ->
        {:ok, bank_account} = BankAccount.deposit(bank_account, 10)
        {:ok, bank_account} = Store.commit(bank_account)
        bank_account
      end)
    else
      bank_account
    end
  end

  test "will poll from the eventstore for events" do
    %BankAccount{id: id} = seed(10)
    {:ok, events} = Store.read_stream_forward(id)
    assert length(events) == 10

    Enum.each(events, fn(event) ->
      enriched = {:bloated, {:enriched, event}}
      assert_receive ^enriched, 10000
    end)
  end
end
