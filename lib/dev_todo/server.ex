defmodule DevTodo.Server do
  @moduledoc false

  use GenServer

  require Logger

  alias DevTodo.{File, Parser, Task}

  @debounce_ms 500

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def list_tasks do
    GenServer.call(__MODULE__, :list_tasks)
  end

  def list_statuses do
    GenServer.call(__MODULE__, :list_statuses)
  end

  def get_task(id) do
    GenServer.call(__MODULE__, {:get_task, id})
  end

  def create_task(attrs) do
    GenServer.call(__MODULE__, {:create_task, attrs})
  end

  def update_task(id, attrs) do
    GenServer.call(__MODULE__, {:update_task, id, attrs})
  end

  def delete_task(id) do
    GenServer.call(__MODULE__, {:delete_task, id})
  end

  def move_task(task_id, target_status, prev_id, next_id) do
    GenServer.call(__MODULE__, {:move_task, task_id, target_status, prev_id, next_id})
  end

  def reload do
    GenServer.cast(__MODULE__, :reload)
  end

  def prefix do
    GenServer.call(__MODULE__, :prefix)
  end

  def warnings do
    GenServer.call(__MODULE__, :warnings)
  end

  def repo_url do
    GenServer.call(__MODULE__, :repo_url)
  end

  def label_colors do
    GenServer.call(__MODULE__, :label_colors)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(DevTodo.config!(:pubsub), topic())
  end

  defp topic, do: "dev_todo"

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, {statuses, tasks, header, prefix, label_colors, raw_lines, warnings}} =
      File.read_tasks()

    tasks = maybe_fix_duplicate_ids(tasks, statuses)

    {:ok,
     %{
       statuses: statuses,
       tasks: tasks,
       header: header,
       prefix: prefix,
       label_colors: label_colors,
       raw_lines: raw_lines,
       warnings: warnings,
       next_id: compute_next_id(tasks),
       mtime: file_mtime(),
       just_wrote: false,
       debounce_ref: nil,
       repo_url: parse_repo_url()
     }}
  end

  @impl true
  def handle_call(:list_tasks, _from, state) do
    state = maybe_reload_from_disk(state)
    {:reply, state.tasks, state}
  end

  def handle_call(:list_statuses, _from, state) do
    state = maybe_reload_from_disk(state)
    {:reply, state.statuses, state}
  end

  def handle_call(:prefix, _from, state) do
    {:reply, state.prefix, state}
  end

  def handle_call(:warnings, _from, state) do
    {:reply, state.warnings, state}
  end

  def handle_call(:repo_url, _from, state) do
    {:reply, state.repo_url, state}
  end

  def handle_call(:label_colors, _from, state) do
    {:reply, state.label_colors, state}
  end

  def handle_call({:get_task, id}, _from, state) do
    task = find_task(state.tasks, to_id(id))
    {:reply, task, state}
  end

  def handle_call({:create_task, attrs}, _from, state) do
    status = Map.get(attrs, :status, List.first(state.statuses, :todo))
    current = Map.get(state.tasks, status, [])
    id = state.next_id

    task = %Task{
      id: id,
      title: attrs.title,
      description: Map.get(attrs, :description, ""),
      status: status,
      assignees: Map.get(attrs, :assignees, []),
      pr: Map.get(attrs, :pr),
      attachments: Map.get(attrs, :attachments, []),
      labels: Map.get(attrs, :labels, []),
      position: length(current)
    }

    new_tasks = Map.put(state.tasks, status, current ++ [task])
    state = write_and_broadcast(%{state | next_id: id + 1}, new_tasks)
    {:reply, {:ok, task}, state}
  end

  def handle_call({:update_task, id, attrs}, _from, state) do
    id = to_id(id)

    new_tasks =
      update_in_tasks(state.tasks, id, fn task ->
        task
        |> maybe_update(:title, attrs)
        |> maybe_update(:description, attrs)
        |> maybe_update(:assignees, attrs)
        |> maybe_update(:pr, attrs)
        |> maybe_update(:attachments, attrs)
        |> maybe_update(:labels, attrs)
      end)

    state = write_and_broadcast(state, new_tasks)
    task = find_task(new_tasks, id)
    {:reply, {:ok, task}, state}
  end

  def handle_call({:delete_task, id}, _from, state) do
    id = to_id(id)

    new_tasks =
      Map.new(state.tasks, fn {status, tasks} ->
        {status, Enum.reject(tasks, &(&1.id == id)) |> reindex()}
      end)

    state = write_and_broadcast(state, new_tasks)
    {:reply, :ok, state}
  end

  def handle_call({:move_task, task_id, target_status, prev_id, next_id}, _from, state) do
    target_status = normalize_status(target_status, state.statuses)
    task_id = to_id(task_id)
    prev_id = to_id(prev_id)
    next_id = to_id(next_id)

    case find_task(state.tasks, task_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      task ->
        # Remove from old position
        old_tasks =
          state.tasks
          |> Map.update!(task.status, fn tasks ->
            Enum.reject(tasks, &(&1.id == task_id))
          end)

        # Insert at new position in target column
        target_list = Map.get(old_tasks, target_status, [])
        insert_index = find_insert_index(target_list, prev_id, next_id)

        moved_task = %{task | status: target_status}
        new_list = List.insert_at(target_list, insert_index, moved_task)

        new_tasks =
          old_tasks
          |> Map.put(target_status, reindex(new_list))
          |> Map.new(fn {s, tasks} -> {s, reindex(tasks)} end)

        state = write_and_broadcast(state, new_tasks)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_cast(:reload, %{just_wrote: true} = state) do
    Logger.debug("[DevTodo] Reload skipped (self-triggered write)")
    {:noreply, state}
  end

  def handle_cast(:reload, state) do
    {elapsed, result} = :timer.tc(fn -> File.read_tasks() end)

    case result do
      {:ok, {statuses, tasks, header, prefix, label_colors, raw_lines, warnings}} ->
        task_count = tasks |> Map.values() |> List.flatten() |> length()
        warning_count = length(warnings)

        Logger.debug(
          "[DevTodo] Reloaded #{Path.basename(File.todo_path())} (#{task_count} tasks, #{warning_count} warnings, #{div(elapsed, 1000)}ms)"
        )

        broadcast(prefix, statuses, tasks, label_colors, warnings)

        {:noreply,
         %{
           state
           | statuses: statuses,
             tasks: tasks,
             header: header,
             prefix: prefix,
             label_colors: label_colors,
             raw_lines: raw_lines,
             warnings: warnings,
             next_id: compute_next_id(tasks),
             mtime: file_mtime()
         }}

      {:error, reason} ->
        Logger.debug("[DevTodo] Reload failed: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:clear_debounce, state) do
    {:noreply, %{state | just_wrote: false, debounce_ref: nil}}
  end

  # Private helpers

  defp write_and_broadcast(state, tasks) do
    {elapsed, _} =
      :timer.tc(fn -> File.write_tasks(state.statuses, tasks, state.header, state.raw_lines) end)

    task_count = tasks |> Map.values() |> List.flatten() |> length()

    Logger.debug(
      "[DevTodo] Wrote #{Path.basename(File.todo_path())} (#{task_count} tasks in #{div(elapsed, 1000)}ms)"
    )

    if state.debounce_ref, do: Process.cancel_timer(state.debounce_ref)
    ref = Process.send_after(self(), :clear_debounce, @debounce_ms)

    broadcast(state.prefix, state.statuses, tasks, state.label_colors, state.warnings)
    %{state | tasks: tasks, mtime: file_mtime(), just_wrote: true, debounce_ref: ref}
  end

  defp broadcast(prefix, statuses, tasks, label_colors, warnings) do
    Phoenix.PubSub.broadcast(
      DevTodo.config!(:pubsub),
      topic(),
      {:tasks_updated, prefix, statuses, tasks, label_colors, warnings}
    )
  end

  defp find_task(tasks, id) do
    tasks
    |> Map.values()
    |> List.flatten()
    |> Enum.find(&(&1.id == id))
  end

  defp update_in_tasks(tasks, id, fun) do
    Map.new(tasks, fn {status, task_list} ->
      updated =
        Enum.map(task_list, fn task ->
          if task.id == id, do: fun.(task), else: task
        end)

      {status, updated}
    end)
  end

  defp maybe_update(task, field, attrs) do
    case Map.get(attrs, field) do
      nil -> task
      value -> Map.put(task, field, value)
    end
  end

  defp find_insert_index(list, prev_id, next_id) do
    cond do
      is_integer(prev_id) ->
        case Enum.find_index(list, &(&1.id == prev_id)) do
          nil -> length(list)
          idx -> idx + 1
        end

      is_integer(next_id) ->
        case Enum.find_index(list, &(&1.id == next_id)) do
          nil -> 0
          idx -> idx
        end

      true ->
        length(list)
    end
  end

  defp compute_next_id(tasks) do
    max_id =
      tasks
      |> Map.values()
      |> List.flatten()
      |> Enum.map(& &1.id)
      |> Enum.max(fn -> 0 end)

    max_id + 1
  end

  defp to_id(val) when is_integer(val), do: val
  defp to_id(val) when is_binary(val) and val != "", do: String.to_integer(val)
  defp to_id(_), do: nil

  defp reindex(tasks) do
    tasks |> Enum.with_index() |> Enum.map(fn {t, i} -> %{t | position: i} end)
  end

  defp normalize_status(status, _statuses) when is_atom(status), do: status

  defp normalize_status(status, statuses) when is_binary(status) do
    atom = String.to_existing_atom(status)
    if atom in statuses, do: atom, else: List.first(statuses, :todo)
  rescue
    ArgumentError -> List.first(statuses, :todo)
  end

  defp parse_repo_url do
    case System.cmd("git", ["remote", "get-url", "origin"], stderr_to_stdout: true) do
      {url, 0} -> url |> String.trim() |> remote_to_github_url()
      _ -> nil
    end
  end

  defp remote_to_github_url("git@github.com:" <> rest) do
    rest |> String.trim_trailing(".git") |> then(&"https://github.com/#{&1}")
  end

  defp remote_to_github_url("https://github.com/" <> _ = url) do
    String.trim_trailing(url, ".git")
  end

  defp remote_to_github_url(_), do: nil

  defp maybe_reload_from_disk(state) do
    current_mtime = file_mtime()

    if current_mtime != state.mtime do
      case File.read_tasks() do
        {:ok, {statuses, tasks, header, prefix, label_colors, raw_lines, warnings}} ->
          %{
            state
            | statuses: statuses,
              tasks: tasks,
              header: header,
              prefix: prefix,
              label_colors: label_colors,
              raw_lines: raw_lines,
              warnings: warnings,
              next_id: compute_next_id(tasks),
              mtime: current_mtime
          }

        _ ->
          state
      end
    else
      state
    end
  end

  defp file_mtime do
    case Elixir.File.stat(File.todo_path()) do
      {:ok, %{mtime: mtime}} -> mtime
      _ -> nil
    end
  end

  # If any IDs are duplicated, reassign them sequentially and return fixed tasks.
  defp maybe_fix_duplicate_ids(tasks, statuses) do
    if Parser.has_duplicate_ids?(tasks) do
      {fixed, _seen} =
        Enum.reduce(statuses, {tasks, MapSet.new()}, fn status, {acc, seen} ->
          {updated, seen} =
            Enum.map_reduce(Map.get(acc, status, []), seen, fn task, seen ->
              if MapSet.member?(seen, task.id) do
                new_id = compute_next_id(acc)
                {%{task | id: new_id}, MapSet.put(seen, new_id)}
              else
                {task, MapSet.put(seen, task.id)}
              end
            end)

          {Map.put(acc, status, updated), seen}
        end)

      fixed
    else
      tasks
    end
  end
end
