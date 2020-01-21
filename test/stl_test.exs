defmodule StlTest do
  use ExUnit.Case
  doctest STL

  test "greets the world" do
    assert STL.hello() == :world
  end
end
