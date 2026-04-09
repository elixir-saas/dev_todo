defmodule DevTodo.File do
  @moduledoc false

  alias DevTodo.Parser

  def todo_path do
    Path.expand(DevTodo.config(:todo_path, "TODO.md"))
  end

  @doc """
  Returns `{:ok, {statuses, tasks, header, prefix, label_colors, raw_lines, warnings}}` or `{:error, reason}`.
  """
  def read_tasks do
    case File.read(todo_path()) do
      {:ok, content} ->
        header = extract_header(content)
        prefix = extract_prefix(header)
        label_colors = extract_label_colors(header)
        {statuses, tasks, raw_lines, warnings} = Parser.parse(content)
        {:ok, {statuses, tasks, header, prefix, label_colors, raw_lines, warnings}}

      {:error, :enoent} ->
        {:ok,
         {[:in_progress, :todo, :backlog, :done], %{}, default_header(), "DEV", %{}, %{}, []}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def write_tasks(statuses, tasks_by_status, header, raw_lines \\ %{}) do
    content = Parser.serialize(statuses, tasks_by_status, header, raw_lines)
    File.write(todo_path(), content)
  end

  # Extract everything before the first ## heading (the HTML comment block)
  defp extract_header(content) do
    content
    |> String.split("\n")
    |> Enum.take_while(fn line -> not String.starts_with?(String.trim(line), "## ") end)
    |> Enum.join("\n")
    |> String.trim_trailing()
  end

  defp extract_prefix(header) do
    case Regex.run(~r/- Prefix:\s*(\w+)/, header) do
      [_, prefix] -> prefix
      nil -> "DEV"
    end
  end

  defp extract_label_colors(header) do
    case Regex.run(~r/- Labels:\s*(.+)/, header) do
      [_, assignments] ->
        assignments
        |> String.split(",")
        |> Enum.reduce(%{}, fn pair, acc ->
          case String.trim(pair) |> String.split("=", parts: 2) do
            [name, color] -> Map.put(acc, String.trim(name), String.trim(color))
            _ -> acc
          end
        end)

      nil ->
        %{}
    end
  end

  defp default_header do
    """
    <!--
    TODO.md — Project Task Board

    - Prefix: DEV
    - Labels: bug=#ef4444, feature=#3b82f6, docs=#22c55e

    Rules for AI agents editing this file:
    - Sections are defined by ## headings (e.g., ## In Progress, ## Todo)
    - To add a new status, add a new ## heading — the board adapts automatically
    - Task format: `- [N] Task title @assignee #pr:123 #label:bug` where N is a number
    - IDs are auto-incrementing integers (the board displays them as PREFIX-N)
    - To move a task, cut the line and paste under the target section header
    - Order within a section = priority (top = highest)
    - Descriptions: indent lines under a task with 2+ spaces
    - Labels: tag with `#label:name` (multiple allowed)
    - Attachments: reference with `^path/to/file`
    - Do not reorder or remove existing section headers
    -->\
    """
  end
end
