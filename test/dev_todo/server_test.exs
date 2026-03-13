defmodule DevTodo.ServerTest do
  use ExUnit.Case

  alias DevTodo.Server

  @todo_content """
  <!--
  TODO.md — Project Task Board

  - Prefix: TST

  Rules for AI agents editing this file:
  -->

  ## In Progress

  - [1] First task @alice

  ## Todo

  - [2] Second task
    Has a description

  ## Done

  - [3] Completed task #pr:5
  """

  setup do
    tmp_dir = System.tmp_dir!()
    path = Path.join(tmp_dir, "server_test_todo_#{System.unique_integer([:positive])}.md")
    File.write!(path, @todo_content)
    Application.put_env(:dev_todo, :todo_path, path)
    Application.put_env(:dev_todo, :pubsub, DevTodo.TestPubSub)

    start_supervised!({Phoenix.PubSub, name: DevTodo.TestPubSub})
    start_supervised!(Server)

    on_exit(fn ->
      File.rm(path)
      Application.delete_env(:dev_todo, :todo_path)
      Application.delete_env(:dev_todo, :pubsub)
    end)

    %{path: path}
  end

  describe "list_tasks/0" do
    test "returns tasks grouped by status" do
      tasks = Server.list_tasks()
      assert length(tasks[:in_progress]) == 1
      assert length(tasks[:todo]) == 1
      assert length(tasks[:done]) == 1
    end
  end

  describe "list_statuses/0" do
    test "returns statuses in order" do
      assert Server.list_statuses() == [:in_progress, :todo, :done]
    end
  end

  describe "prefix/0" do
    test "returns the configured prefix" do
      assert Server.prefix() == "TST"
    end
  end

  describe "get_task/1" do
    test "returns a task by id" do
      task = Server.get_task(1)
      assert task.title == "First task"
      assert task.assignees == ["alice"]
    end

    test "returns a task by string id" do
      task = Server.get_task("2")
      assert task.title == "Second task"
    end

    test "returns nil for nonexistent task" do
      assert Server.get_task(999) == nil
    end
  end

  describe "create_task/1" do
    test "creates a task and assigns next id" do
      {:ok, task} = Server.create_task(%{title: "New task", status: :todo})
      assert task.id == 4
      assert task.title == "New task"
      assert task.status == :todo

      tasks = Server.list_tasks()
      assert length(tasks[:todo]) == 2
    end

    test "writes to disk", %{path: path} do
      {:ok, _task} = Server.create_task(%{title: "Persisted", status: :todo})
      content = File.read!(path)
      assert content =~ "Persisted"
    end

    test "broadcasts update" do
      Server.subscribe()
      {:ok, _task} = Server.create_task(%{title: "Broadcast test", status: :todo})
      assert_receive {:tasks_updated, _prefix, _statuses, _tasks, _warnings}, 1000
    end
  end

  describe "update_task/2" do
    test "updates task fields" do
      {:ok, task} = Server.update_task(1, %{title: "Updated title"})
      assert task.title == "Updated title"

      refreshed = Server.get_task(1)
      assert refreshed.title == "Updated title"
    end

    test "updates description" do
      {:ok, task} = Server.update_task(2, %{description: "New desc"})
      assert task.description == "New desc"
    end

    test "only updates provided fields" do
      {:ok, task} = Server.update_task(1, %{title: "New title"})
      assert task.assignees == ["alice"]
    end
  end

  describe "delete_task/1" do
    test "removes the task" do
      :ok = Server.delete_task(1)
      assert Server.get_task(1) == nil
      assert length(Server.list_tasks()[:in_progress]) == 0
    end
  end

  describe "move_task/4" do
    test "moves task to a different status" do
      :ok = Server.move_task(1, :todo, nil, nil)
      task = Server.get_task(1)
      assert task.status == :todo
      assert length(Server.list_tasks()[:in_progress]) == 0
    end

    test "moves task between other tasks" do
      {:ok, _} = Server.create_task(%{title: "Extra", status: :todo})
      :ok = Server.move_task(1, :todo, 2, nil)
      todo_tasks = Server.list_tasks()[:todo]
      ids = Enum.map(todo_tasks, & &1.id)
      assert hd(ids) == 2
      assert 1 in ids
    end

    test "returns error for nonexistent task" do
      assert {:error, :not_found} = Server.move_task(999, :todo, nil, nil)
    end
  end

  describe "warnings/0" do
    test "returns empty list for valid file" do
      assert Server.warnings() == []
    end
  end

  describe "duplicate ID fixing" do
    @duplicate_content """
    <!--
    TODO.md — Project Task Board

    - Prefix: TST
    -->

    ## Todo

    - [1] First task
    - [1] Duplicate of first

    ## Done

    - [2] Done task
    - [1] Another duplicate
    """

    test "reassigns duplicate IDs on startup" do
      stop_supervised!(Server)

      tmp_dir = System.tmp_dir!()
      path = Path.join(tmp_dir, "dedup_test_#{System.unique_integer([:positive])}.md")
      File.write!(path, @duplicate_content)
      Application.put_env(:dev_todo, :todo_path, path)

      start_supervised!(Server)

      tasks = Server.list_tasks()
      all_ids = tasks |> Map.values() |> List.flatten() |> Enum.map(& &1.id)

      assert length(all_ids) == length(Enum.uniq(all_ids)),
             "Expected unique IDs, got: #{inspect(all_ids)}"

      File.rm(path)
    end

    test "preserves first occurrence of each ID" do
      stop_supervised!(Server)

      tmp_dir = System.tmp_dir!()
      path = Path.join(tmp_dir, "dedup_test_#{System.unique_integer([:positive])}.md")
      File.write!(path, @duplicate_content)
      Application.put_env(:dev_todo, :todo_path, path)

      start_supervised!(Server)

      tasks = Server.list_tasks()
      first_todo = hd(tasks[:todo])
      assert first_todo.id == 1
      assert first_todo.title == "First task"

      File.rm(path)
    end

    test "does not alter tasks when no duplicates exist" do
      tasks = Server.list_tasks()
      assert Server.get_task(1).title == "First task"
      assert Server.get_task(2).title == "Second task"
      assert Server.get_task(3).title == "Completed task"
      assert tasks |> Map.values() |> List.flatten() |> length() == 3
    end
  end
end
