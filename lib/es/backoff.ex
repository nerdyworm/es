defmodule ES.Backoff do
  def backoff(attempts, base \\ 100, limit \\ 5000) do
    exp = min(limit / 2, :math.pow(2, attempts) * base) |> round()
    jitter = :rand.uniform(exp)
    exp + jitter
  end
end
