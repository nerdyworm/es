defmodule ES.Aggregate do
  @type t :: module

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Kernel, except: [apply: 2]
      import Ecto.Changeset
      import ES.Aggregate

      alias Ecto.Changeset

      def new(stream_uuid) do
        aggregate = struct(__MODULE__)
        %{aggregate | id: stream_uuid}
      end

      def stream_uuid(%{id: id, __struct__: module}) when is_integer(id) do
        "#{module}-#{id}"
      end

      def stream_uuid(aggregate) do
        aggregate.id
      end

      def stream_type(%{__struct__: module}) do
        module |> Atom.to_string
      end

      def stream_version(aggregate) do
        aggregate.version
      end

      def replay(%{__struct__: module} = aggregate, events) do
        events
        |> List.wrap()
        |> Enum.reduce(aggregate, fn(event, acc) ->
          %ES.Event{
            event_data: event_data,
            stream_version: stream_version
          } = event

          case module.handle_event(event_data, acc) do
            %Changeset{} = changeset ->
              changeset
              |> change(version: stream_version)
              |> apply_changes()

            aggregate ->
              %{aggregate | version: stream_version, pending: [], changesets: []}
          end
        end)
      end

      def apply(%{pending: pending, __struct__: stream_type} = aggregate, event) do
        data_changeset = event |> event.__struct__.changeset
        if data_changeset.valid? do
          event = apply_changes(data_changeset)

          aggregate =
            event
            |> stream_type.handle_event(aggregate)
            |> append_change(pending: pending ++ [event])

          {:ok, aggregate}
        else
          {:error, data_changeset}
        end
      end

      def preload(aggregate) do
        aggregate
      end

      defoverridable [preload: 1]
    end
  end

  def append_change(%Ecto.Changeset{data: %{changesets: changesets}} = changeset, params) do
    changeset =
      Ecto.Changeset.change(changeset, params)

    changeset
    |> Ecto.Changeset.change(changesets: changesets ++ [changeset])
    |> Ecto.Changeset.apply_changes()
  end

  def append_change(aggregate, params) do
    Ecto.Changeset.change(aggregate)
    |> append_change(params)
  end
end
