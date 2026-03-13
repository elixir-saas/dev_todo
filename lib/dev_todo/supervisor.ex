defmodule DevTodo.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if DevTodo.config(:pubsub) do
      children = [
        DevTodo.Server,
        DevTodo.Watcher
      ]

      Supervisor.init(children, strategy: :one_for_one)
    else
      :ignore
    end
  end
end
