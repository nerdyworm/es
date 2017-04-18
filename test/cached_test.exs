defmodule EsDyanmodbTest do
  use ExUnit.Case

  setup do
    Application.put_env(:es, :cache_ttl, 1)
    :ok
  end

  test "it caches things" do
    :ok = ES.Cache.write_cache("testing", :something)
    assert {:ok, :something} = ES.Cache.read_cache("testing")
    :timer.sleep(500)
    assert {:ok, :something} = ES.Cache.read_cache("testing")
    :timer.sleep(500)
    assert {:ok, :something} = ES.Cache.read_cache("testing")
    :timer.sleep(3000)
    assert :notfound = ES.Cache.read_cache("testing")
  end
end
