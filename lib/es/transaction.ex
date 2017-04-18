defmodule ES.Transaction do
  import Ecto.Changeset

  require Logger

  def commit(store, aggregate) do
    run(store, aggregate)
  end

  def run(store, %{version: version, changesets: changesets} = aggregate) do
    module = aggregate.__struct__
    source = module.__schema__(:source)
    last   = List.last(changesets)

    changesets =
      Enum.map(changesets, fn(changeset) ->
        if last == changeset do
          changeset
          |> change(version: version + 1, pending: [], changesets: [])
        else
          changeset
        end
      end)

    if source == nil do
      commit_pending(store, aggregate, changesets)
    else
      run_with_repo(store, aggregate, changesets)
    end
  end

  defp commit_pending(store, %{pending: pending} = aggregate, changesets) do
    pristine =
      Enum.reduce(changesets, aggregate, fn(changeset, _) ->
        apply_changes(changeset)
      end)

    case store.append_to_stream(pristine, pending) do
      {:ok, events} ->
        {:ok, pristine, events}

      {:error, :version_conflict} ->
        {:error, :version_conflict}
    end
  end

  def run_with_repo(store, %{pending: pending}, changesets) do
    repo = store.repo()

    results =
      repo.transaction fn ->
        pristine =
          Enum.reduce(changesets, nil, fn(%{data: %{version: version}} = changeset, aggregate) ->
            # first event/changeset needs to be inserted
            # everything else is an update
            if version == 0 && aggregate == nil do
              repo.insert!(changeset)
            else
              repo.update!(changeset)
            end
          end)

        case store.append_to_stream(pristine, pending) do
          {:ok, events} ->
            {:ok, pristine, events}

          {:error, :version_conflict} ->
            repo.rollback(:version_conflict)
        end
      end

    case results do
      {:ok, {:ok, aggregate, events}} ->
        {:ok, aggregate, events}

      {:error, :version_conflict} ->
        {:error, :version_conflict}
    end
  end
end
