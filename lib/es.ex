defmodule ES do
  @moduledoc """
  Documentation for ES.

   ## Event Storage Simple Example
         iex> {:ok, _} = EventStore.start_link
         ...> {:ok, aggregate} = Person.create(ES.uuid, "bob")
         ...> {:ok, aggregate} = EventStore.commit(aggregate)
         ...> {aggregate.name, aggregate.version}
         {"bob", 1}

  """

  defmodule VersionConflictError do
    defexception message: "Expected version mismatch"
  end

  defmodule AppendRetryLimitReachedError do
    defexception message: "Excedded the number of tries"
  end

  def uuid do
    UUID.uuid4
  end

  def timestamp do
    :os.system_time(:seconds)
  end
end
