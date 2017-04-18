defmodule ES.EventStream.EctoTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  defmodule Store do
    use ES.EventStore,
      adapter: ES.Storage.Ecto, repo: ES.Repo
  end

  defmodule Stage do
    use ES.EventStream,
      adapter: ES.Stages.Ecto,
      consumers: [Consumer],
      store: Store,
      repo: ES.Repo
  end

  setup do
    Process.register(self(), :testing)
    :ok
  end

  defmodule App do
    def start() do
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
    {:ok, pid} = App.start
    on_exit(fn ->
      ref = Process.monitor(pid)
      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      end
    end)

    bank_account = seed(5)
    {:ok, events} = Store.read_stream_forward(bank_account)
    assert length(events) == 5

    Enum.each(events, fn(event) ->
      assert_receive ^event, 3000
    end)
  end

  defmodule CrashyStage do
    use ES.EventStream,
      adapter: ES.Stages.Ecto,
      consumers: [BadConsumer],
      store: Store,
      repo: ES.Repo
  end

  defmodule Crashy do
    def start() do
      import Supervisor.Spec

      children = [
        worker(Store, []),
        worker(CrashyStage, []),
      ]

      Supervisor.start_link(children, [strategy: :one_for_one, max_restarts: 100])
    end
  end

  test "failing to checkpoint within a time period will cause the stream to nack the pending events and continue" do
    {:ok, pid} = Crashy.start()
    on_exit(fn ->
      ref = Process.monitor(pid)
      receive do
        {:DOWN, ^ref, _, _, _} -> :ok
      end
    end)

    fun = fn() ->
      assert :ok =  CrashyStage.notify(%ES.Event{event_id: 1})
      assert :ok =  CrashyStage.notify(%ES.Event{event_id: 2})
      assert_receive %ES.Event{event_id: 2}, 5000

      assert :ok = CrashyStage.notify(%ES.Event{event_id: 3})
      assert_receive %ES.Event{event_id: 3}, 5000
      :timer.sleep(100)
    end

    assert capture_log(fun) =~ "nacking event_id=1"
    assert [error] = ES.Repo.all(ES.Storage.Ecto.EventError)
    assert error.event_id == "1"
  end
end
