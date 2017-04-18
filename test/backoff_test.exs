defmodule ES.BackoffTest do
  use ExUnit.Case

  #test "backoff 0" do
    #Enum.each(0..5, fn(i) ->
      #ms1 =  ES.Backoff.backoff(i, 10)
      #ms2 =  ES.Backoff.backoff(i, 10)
      #assert "#{ms1}ms" != "#{ms2}ms"
    #end)
  #end
end
