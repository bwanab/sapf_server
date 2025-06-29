defmodule SAPFServerTest do
  use ExUnit.Case
  doctest SAPFServer

  test "greets the world" do
    assert SAPFServer.hello() == :world
  end
end
