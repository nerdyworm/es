defmodule ES.Stages do
  import Supervisor.Spec

  def enrichers(stream, options) do
    enrichers = options[:enrichers] || []
    Enum.reduce(enrichers, [], fn(enricher, acc) ->
      subscribe_to =
        if acc == [] do
          stream
        else
          {last, _} = List.last(acc)
          Module.concat(stream, last)
        end

        options = [subscribe_to: [subscribe_to]]
        acc ++ [{enricher, options}]
    end)
    |> Enum.map(fn({enricher, options}) ->
      worker(enricher, [stream, options])
    end)
  end

  def consumers(stream, options) do
    enrichers = Keyword.get(options, :enrichers, [])
    consumers = Keyword.get(options, :consumers, [])

    producer =
      if enrichers == [] do
        stream
      else
        enricher = List.last(enrichers)
        Module.concat(stream, enricher)
      end

    options = Keyword.put(options, :subscribe_to, [producer])
    Enum.map(consumers, fn(consumer) ->
      worker(consumer, [stream, options])
    end)
  end
end
