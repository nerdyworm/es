defmodule ES.Encoder do
  alias Poison.Decode

  def encode(term) do
    term
    |> Poison.encode!()
    |> :zlib.gzip()
    |> Base.encode64
  end

  def decode(binary, config \\ [])
  def decode(value, config) when is_map(value) do
    config = normalize_as(config)
    value |> Decode.decode(config)
  end

  def decode(binary, config) do
    config = normalize_as(config)

    binary
    |> Base.decode64!
    |> :zlib.gunzip()
    |> Poison.decode!(config)
  end

    # basically b/c I always forget to pass a struct as
  defp normalize_as(config) do
    as = Keyword.get(config, :as)
    if as && is_atom(as) do
      [as: struct(as)]
    else
      config
    end
  end
end
