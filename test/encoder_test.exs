defmodule Es.EncoderTest do
  use ExUnit.Case

  @encoded ~s({"timestamp":1492359333,"stream_version":1,"stream_uuid":"ae2d0086-ee99-4c0a-837a-36b3b8c4f9ce","stream_type":"Elixir.BankAccount","event_type":"Elixir.BankAccount.Opened","event_sequence":1,"event_id":"ae2d0086-ee99-4c0a-837a-36b3b8c4f9ce.1.1","event_data":{"uuid":"ae2d0086-ee99-4c0a-837a-36b3b8c4f9ce","name":"bob's bank account"}})

  test "posion can decode json" do
    assert %ES.Event{event_data: event_data} = Poison.decode!(@encoded, as: %ES.Event{})
    assert %BankAccount.Opened{} = event_data
    assert event_data.name == "bob's bank account"
  end
end
