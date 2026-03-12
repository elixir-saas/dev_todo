defmodule DevTodoTest do
  use ExUnit.Case
  doctest DevTodo

  test "greets the world" do
    assert DevTodo.hello() == :world
  end
end
