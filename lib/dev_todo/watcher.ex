defmodule DevTodo.Watcher do
  @moduledoc false

  use GenServer

  alias DevTodo.{File, Server}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    path = File.todo_path()
    {:ok, pid} = FileSystem.start_link(dirs: [Path.dirname(path)])
    FileSystem.subscribe(pid)
    {:ok, %{watcher_pid: pid, watch_path: path}}
  end

  @impl true
  def handle_info({:file_event, _pid, {path, _events}}, state) do
    if to_string(path) |> Path.expand() == state.watch_path do
      Server.reload()
    end

    {:noreply, state}
  end

  def handle_info({:file_event, _pid, :stop}, state) do
    {:noreply, state}
  end
end
