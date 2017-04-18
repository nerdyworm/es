defmodule EsNonDbBackedTest do
  use ExUnit.Case

  def consumers() do
    [Consumer]
  end

  def checkpoint(_event) do
    :ok
  end

  setup do
    Process.register(self(), :testing)
    :ok
  end

  test "commit and changes" do
    TestEventStore.add_stream(__MODULE__)

    uuid = UUID.uuid4
    {:ok, aggregate} = Workflow.start(uuid, "workflowsssss")
    {:ok, aggregate} = TestEventStore.commit(aggregate)
    assert aggregate.id == uuid
    assert aggregate.name == "workflowsssss"
    assert aggregate.version == 1

    {:ok, events} = TestEventStore.read_stream_forward(aggregate)
    assert Enum.map(events, &(&1.stream_version)) == [1]

    {:ok, aggregate} = Workflow.complete(aggregate)
    {:ok, aggregate} = TestEventStore.commit(aggregate)

    {:ok, events} = TestEventStore.read_stream_forward(aggregate)
    assert Enum.map(events, &(&1.stream_version)) == [1, 2]

    replayed = Workflow.replay(%Workflow{}, events)
    assert replayed.id == uuid
    assert replayed.name == "workflowsssss"
    assert replayed.version == 2

    gotten = TestEventStore.get(Workflow, uuid)
    assert gotten.id == uuid
    assert gotten.name == "workflowsssss"
    assert gotten.version == 2

    Enum.each(events, fn(event) ->
      assert_received ^event
    end)
  end

  test "apply and commit" do
    TestEventStore.add_stream(__MODULE__)

    uuid = UUID.uuid4
    {:ok, aggregate} = Workflow.start(uuid, "workflowsssss")
    {:ok, aggregate} = TestEventStore.commit(aggregate)

    {:ok, aggregate} = Workflow.apply(aggregate, %Workflow.Completed{at: 1})
    assert aggregate.version == 1
    assert aggregate.pending == [%Workflow.Completed{at: 1}]

    {:ok, aggregate} = TestEventStore.commit(aggregate)
    assert aggregate.version == 2
    assert aggregate.pending == []

    gotten = TestEventStore.get(Workflow, uuid)
    assert gotten.version == 2
    assert gotten.pending == []
    assert gotten.name == "workflowsssss"

    {:ok, events} = TestEventStore.read_stream_forward(aggregate)
    assert length(events) == 2

    Enum.each(events, fn(event) ->
      assert_received ^event
    end)
  end

  test "person example" do
    defmodule EventStore, do: use ES.EventStore, adapter: ES.Storage.Memory, inline: true

    {:ok, _pid} = EventStore.start_link

    {:ok, aggregate} = Person.create(UUID.uuid4, "bob")
    assert aggregate.version == 0
    assert aggregate.pending == [%Person.Created{uuid: aggregate.id, name: "bob"}]

    {:ok, aggregate} = EventStore.commit(aggregate)
    assert aggregate.version == 1

    {:ok, [created]} = EventStore.read_stream_forward(aggregate)
    assert created.event_data.uuid == aggregate.id
    assert created.event_data.name == "bob"

    person = EventStore.get(Person, aggregate.id)
    assert person == aggregate
  end
end
