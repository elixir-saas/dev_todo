defmodule DevTodo.FileTest do
  use ExUnit.Case, async: true

  alias DevTodo.File, as: TodoFile

  @todo_content """
  <!--
  TODO.md — Project Task Board

  - Prefix: APP

  Rules for AI agents editing this file:
  -->

  ## In Progress

  - [1] Task one @alice

  ## Todo

  - [2] Task two
    A description line

  ## Done

  - [3] Finished task #pr:10
  """

  setup do
    tmp_dir = System.tmp_dir!()
    path = Path.join(tmp_dir, "test_todo_#{System.unique_integer([:positive])}.md")
    File.write!(path, @todo_content)
    Application.put_env(:dev_todo, :todo_path, path)

    on_exit(fn ->
      File.rm(path)
      Application.delete_env(:dev_todo, :todo_path)
    end)

    %{path: path}
  end

  describe "read_tasks/0" do
    test "reads and parses TODO.md", %{path: _path} do
      {:ok, {statuses, tasks, _header, prefix, _raw_lines, _warnings}} = TodoFile.read_tasks()

      assert statuses == [:in_progress, :todo, :done]
      assert prefix == "APP"
      assert length(tasks[:in_progress]) == 1
      assert hd(tasks[:in_progress]).title == "Task one"
      assert hd(tasks[:in_progress]).assignees == ["alice"]
    end

    test "parses descriptions" do
      {:ok, {_statuses, tasks, _header, _prefix, _raw_lines, _warnings}} = TodoFile.read_tasks()

      task = hd(tasks[:todo])
      assert task.description == "A description line"
    end

    test "extracts prefix from header" do
      {:ok, {_statuses, _tasks, _header, prefix, _raw_lines, _warnings}} = TodoFile.read_tasks()
      assert prefix == "APP"
    end

    test "returns defaults when file does not exist" do
      Application.put_env(:dev_todo, :todo_path, "/tmp/nonexistent_#{System.unique_integer()}.md")
      {:ok, {statuses, tasks, _header, prefix, _raw_lines, _warnings}} = TodoFile.read_tasks()

      assert statuses == [:in_progress, :todo, :backlog, :done]
      assert tasks == %{}
      assert prefix == "DEV"
    end
  end

  describe "write_tasks/4" do
    test "writes tasks to disk and round-trips", %{path: path} do
      {:ok, {statuses, tasks, header, _prefix, raw_lines, _warnings}} = TodoFile.read_tasks()

      :ok = TodoFile.write_tasks(statuses, tasks, header, raw_lines)

      content = File.read!(path)
      assert content =~ "- [1] Task one @alice"
      assert content =~ "- [2] Task two"
      assert content =~ "- [3] Finished task #pr:10"
      assert content =~ "## In Progress"
      assert content =~ "## Done"
    end

    test "preserves descriptions through write", %{path: path} do
      {:ok, {statuses, tasks, header, _prefix, raw_lines, _warnings}} = TodoFile.read_tasks()

      :ok = TodoFile.write_tasks(statuses, tasks, header, raw_lines)

      content = File.read!(path)
      assert content =~ "  A description line"
    end
  end
end
