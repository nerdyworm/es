defmodule ES.Util do
  alias ES.Commit

  def human_filesize(%Commit{events: events}) do
    Enum.reduce(events, 0, fn(event, total) ->
      total + :erlang.size(event.data)
    end)
    |> human_filesize()
  end

  def human_filesize(size) do
    human_filesize(size, ["b", "kb", "mb", "gb", "tb", "pb"])
  end

  def human_filesize(s, [_|[_|_] = l]) when s >= 1024 do
    human_filesize(s / 1024, l)
  end

  def human_filesize(s, [m|_]) do
    :io_lib.format("~.2f~s", [:erlang.float(s), m])
  end

  def backoff(0) do
    :ok
  end

  def backoff(attempts) do
    ms = ES.Backoff.backoff(attempts + 1)
    :timer.sleep(ms)
    :ok
  end
end
