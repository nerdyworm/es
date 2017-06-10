defmodule ES.StorageAdapterCase do
  use ExUnit.CaseTemplate

  defmodule Handler do
    use ES.EventConsumer

    def handle_event(event) do
      #:timer.sleep(100)
      #IO.puts "[Consumer] consumer: #{inspect event}"
      send(:testing, event)
      :ok
    end

  end

  defmodule EventStream do
    def notify(_store, events) do
      Enum.each(consumers(), fn(handler) ->
        :erlang.apply(handler, :handle_events, [events, self(), __MODULE__])
      end)
    end

    def checkpoint(_event) do
      :ok
    end

    def consumers() do
      [Handler]
    end
  end

  using do
    quote location: :keep do
      test "reads a stream not found", %{store: store} do
        assert {:ok, []} = store.read_stream_forward("not found")
      end

      test "get_event_by_id", %{store: store} do
        assert nil == store.get_event_by_id("1.1.1")
        {:ok, bank_account} = BankAccount.open("bob's bank account")
        {:ok, bank_account} = BankAccount.deposit(bank_account, 10)
        {:ok, bank_account} = store.commit(bank_account)
        {:ok, [event1, event2]} = store.read_stream_forward(bank_account.id)
        assert ^event1 = store.get_event_by_id(event1.event_id)
        assert ^event2 = store.get_event_by_id(event2.event_id)
      end

      test "commit emits events", %{store: store} do
        {:ok, bank_account} = BankAccount.open("bob's bank account")
        {:ok, bank_account} = BankAccount.deposit(bank_account, 10)
        assert {:ok, bank_account} = store.commit(bank_account)
        assert bank_account.version == 1
        assert bank_account.balance == 10

        assert {:ok, events} = store.read_stream_forward(bank_account.id)
        assert_event_data(events, [
          %BankAccount.Opened{name: "bob's bank account", uuid: bank_account.id},
          %BankAccount.Deposited{amount: 10},
        ])

        assert {:ok, events} = store.read_stream_backward(bank_account.id)
        assert_event_data(events, [
          %BankAccount.Deposited{amount: 10},
          %BankAccount.Opened{name: "bob's bank account", uuid: bank_account.id},
        ])
      end

      test "store with streams to notify", %{store: store} do
        :ok = store.add_stream(EventStream)

        stream_uuid = ES.uuid
        event = %BankAccount.Opened{uuid: stream_uuid, name: "bank account"}
        {:ok, bank_account} = BankAccount.apply(%BankAccount{}, event)
        {:ok, bank_account} = store.commit(bank_account)
        assert_received %ES.Event{stream_version: 1 }

        assert {:ok, [opened]} = store.read_stream_forward(stream_uuid)
        assert opened.stream_version == 1
        assert opened.event_sequence == 1
        assert opened.event_data == event

        event = %BankAccount.Deposited{amount: 100}
        assert {:error, :version_conflict} = store.append_to_stream(bank_account, event)

        assert {:ok, bank_account} = store.commit(bank_account, event)
        assert bank_account.version == 2

        assert {:ok, [deposited]} = store.read_stream_forward(stream_uuid, 1)
        assert deposited.stream_version == 2
        assert deposited.event_sequence == 1
        assert deposited.event_data == event

        {:ok, new_bank_account} = store.commit(bank_account, event)
        assert {:ok, [deposited]} = store.read_stream_forward(stream_uuid, 2)
        assert deposited.stream_version == 3
        assert deposited.event_sequence == 1
        assert deposited.event_data == event

        assert {:error, :version_conflict} = store.commit(bank_account, event)
        assert {:ok, appended_to} = store.commit(bank_account, event, :append)
        assert bank_account.version == 2
        assert appended_to.version  == 4
        assert appended_to.balance == 300

        assert_raise ES.AppendRetryLimitReachedError, fn() ->
          store.commit(bank_account, event, :append, 10)
        end

        assert {:ok, [opened]} = store.read_stream_forward(stream_uuid, 0, 1)
        assert opened.stream_version == 1

        assert {:ok, [^opened, deposited]} = store.read_stream_forward(stream_uuid, 0, 2)
        assert deposited.stream_version == 2

        assert {:ok, [^deposited, ^opened]} = store.read_stream_backward(stream_uuid, 3, 2)

        gotten = store.get(BankAccount, stream_uuid)
        assert gotten.id == stream_uuid
      end

      def assert_event_data(incoming, exepected) do
        assert Enum.map(incoming, &(&1.event_data)) == exepected
      end
    end
  end
end
