defmodule EkserTest do
  use ExUnit.Case
  doctest Ekser

  test "greets the world" do
    assert Ekser.hello() == :world
  end
end
