defmodule EsTest do
  use ExUnit.Case
  doctest ES

  #test "get cached" do
    #{:ok, aggregate} = BankAccount.open("ben's bank account")
    #{:ok, [event]} = ES.read_stream_forward(aggregate)

    #cached = ES.get(event)
    #assert cached.id == aggregate.id

    #{:ok, aggregate} = BankAccount.deposit(aggregate, 500)
    #{:ok, [_,last]} = ES.read_stream_forward(aggregate)

    #cached = ES.get(last)
    #assert cached.id == aggregate.id

    #{:ok, aggregate} = BankAccount.deposit(aggregate, 500)
    #{:ok, aggregate} = BankAccount.deposit(aggregate, 500)

    #{:ok, [_,_,_,four]} = ES.read_stream_forward(aggregate)

    #cached = ES.get(four)
    #assert cached.id == aggregate.id
  #end
end
