defmodule DevTodo.Watcher do
  @moduledoc false

  use GenServer

  require Logger

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
  def handle_info({:file_event, _pid, {path, events}}, state) do
    if to_string(path) |> Path.expand() == state.watch_path do
      Logger.debug("[DevTodo] File change detected (#{Enum.join(events, ", ")})")
      Server.reload()
    end

    {:noreply, state}
  end

  def handle_info({:file_event, _pid, :stop}, state) do
    {:noreply, state}
  end
end
