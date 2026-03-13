defmodule DevTodo.Parser do
  @moduledoc false

  import NimbleParsec

  alias DevTodo.Task

  # --- NimbleParsec combinators ---

  # Heading: "## In Progress\n"
  heading =
    ignore(string("## "))
    |> utf8_string([not: ?\n], min: 1)
    |> ignore(string("\n"))
    |> unwrap_and_tag(:heading)

  # Task ID: "[123]"
  task_id =
    ignore(string("["))
    |> integer(min: 1)
    |> ignore(string("]"))

  # Assignee: "@username" or "@hyphen-name"
  assignee =
    ignore(string("@"))
    |> utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 1)
    |> unwrap_and_tag(:assignee)

  # PR reference: "#pr:123"
  pr_ref =
    ignore(string("#pr:"))
    |> integer(min: 1)
    |> unwrap_and_tag(:pr)

  # Attachment: "^path/to/file"
  attachment =
    ignore(string("^"))
    |> utf8_string([not: ?\s, not: ?\n], min: 1)
    |> unwrap_and_tag(:attachment)

  # A plain word (part of the title) — anything that isn't a metadata token
  title_word =
    lookahead_not(choice([string("@"), string("#pr:"), string("^")]))
    |> utf8_string([not: ?\s, not: ?\n], min: 1)
    |> unwrap_and_tag(:title_word)

  # A token in the task body is one of: assignee, pr, attachment, or title word
  token =
    choice([
      assignee,
      pr_ref,
      attachment,
      title_word
    ])

  # Task body: space-separated tokens
  task_body =
    token
    |> repeat(ignore(utf8_string([?\s], min: 1)) |> concat(token))

  # Full task line: "- [N] body\n"
  task_line =
    ignore(string("- "))
    |> concat(task_id)
    |> ignore(string(" "))
    |> concat(task_body)
    |> ignore(choice([string("\n"), eos()]))
    |> tag(:task)

  # A blank line (just whitespace before newline)
  blank_line =
    optional(utf8_string([?\s, ?\t], min: 1))
    |> ignore(string("\n"))
    |> ignore()

  # An indented line (2+ spaces) — description content under a task
  description_line =
    ignore(utf8_string([?\s], min: 2))
    |> utf8_string([not: ?\n], min: 1)
    |> ignore(string("\n"))
    |> unwrap_and_tag(:description_line)

  # A non-blank, non-heading, non-task, non-indented line — captured for preservation
  raw_line =
    utf8_string([not: ?\n], min: 1)
    |> ignore(string("\n"))
    |> unwrap_and_tag(:raw_line)

  # The document is a sequence of headings, task lines, blank lines, and raw lines
  document =
    repeat(
      choice([
        heading,
        task_line,
        description_line,
        blank_line,
        raw_line
      ])
    )

  defparsecp(:parse_document, document)

  # --- Public API ---

  @doc """
  Parses a TODO.md string into `{statuses, tasks, raw_lines, warnings}`.

  - `statuses` — ordered list of status atoms from `##` headings
  - `tasks` — `%{status => [%Task{}]}`
  - `raw_lines` — `%{status => [String.t()]}` unrecognized lines preserved per section
  - `warnings` — `[{status, line}]` for lines that look like tasks but couldn't parse
  """
  def parse(content) when is_binary(content) do
    # Ensure content ends with newline for consistent parsing
    content = if String.ends_with?(content, "\n"), do: content, else: content <> "\n"

    case parse_document(content) do
      {:ok, tokens, "", _, _, _} ->
        build_result(tokens)

      {:ok, tokens, _rest, _, _, _} ->
        build_result(tokens)

      {:error, _, _, _, _, _} ->
        {[], %{}, %{}, []}
    end
  end

  @doc """
  Serializes statuses and tasks back to a TODO.md string.
  Preserves unrecognized lines from `raw_lines` at the end of each section.
  """
  def serialize(statuses, tasks_by_status, header, raw_lines \\ %{}) do
    sections =
      for status <- statuses do
        heading = "## #{status_to_heading(status)}"
        tasks = Map.get(tasks_by_status, status, [])
        task_lines = Enum.map(tasks, &serialize_task/1)
        extra = Map.get(raw_lines, status, [])
        [heading, "" | task_lines ++ extra]
      end

    lines = [header, "" | Enum.intersperse(sections, "")]
    lines |> List.flatten() |> Enum.join("\n") |> Kernel.<>("\n")
  end

  @doc """
  Converts a heading string like "In Progress" to an atom like :in_progress.
  """
  def heading_to_status(heading) do
    heading
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
    |> String.to_atom()
  end

  @doc """
  Converts a status atom like :in_progress to a display name like "In Progress".
  """
  def status_to_heading(status) do
    status
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Returns true if any task ID appears more than once across all statuses.
  """
  def has_duplicate_ids?(tasks) do
    ids = tasks |> Map.values() |> List.flatten() |> Enum.map(& &1.id)
    length(ids) != length(Enum.uniq(ids))
  end

  # --- Private helpers ---

  defp build_result(tokens) do
    {_current, statuses, tasks, raw_lines, warnings} =
      Enum.reduce(tokens, {nil, [], %{}, %{}, []}, fn
        {:heading, heading}, {_current, statuses, tasks, raw, warns} ->
          status = heading_to_status(heading)
          {status, statuses ++ [status], Map.put_new(tasks, status, []), raw, warns}

        {:task, task_tokens}, {current, statuses, tasks, raw, warns}
        when not is_nil(current) ->
          task = build_task(task_tokens, current)
          existing = Map.get(tasks, current, [])
          task = %{task | position: length(existing)}
          {current, statuses, Map.put(tasks, current, existing ++ [task]), raw, warns}

        {:description_line, line}, {current, statuses, tasks, raw, warns}
        when not is_nil(current) ->
          # Append to the last task's description in the current section
          case Map.get(tasks, current, []) do
            [] ->
              {current, statuses, tasks, raw, warns}

            existing ->
              last = List.last(existing)
              desc = if last.description == "", do: line, else: last.description <> "\n" <> line
              updated = List.replace_at(existing, -1, %{last | description: desc})
              {current, statuses, Map.put(tasks, current, updated), raw, warns}
          end

        {:raw_line, line}, {current, statuses, tasks, raw, warns} when not is_nil(current) ->
          existing_raw = Map.get(raw, current, [])
          new_raw = Map.put(raw, current, existing_raw ++ [line])

          new_warns =
            if String.starts_with?(String.trim(line), "- ") do
              warns ++ [{current, line}]
            else
              warns
            end

          {current, statuses, tasks, new_raw, new_warns}

        _, acc ->
          acc
      end)

    {statuses, tasks, raw_lines, warnings}
  end

  defp build_task(tokens, status) do
    # First token is always the integer ID
    [id | rest] = tokens

    assignees =
      for {:assignee, name} <- rest, do: name

    pr =
      case Enum.find(rest, &match?({:pr, _}, &1)) do
        {:pr, num} -> num
        nil -> nil
      end

    attachments =
      for {:attachment, path} <- rest, do: path

    title =
      rest
      |> Enum.filter(&match?({:title_word, _}, &1))
      |> Enum.map_join(" ", fn {:title_word, word} -> word end)

    %Task{
      id: id,
      title: title,
      status: status,
      assignees: assignees,
      pr: pr,
      attachments: attachments,
      position: 0
    }
  end

  defp serialize_task(%Task{} = task) do
    parts = [task.title]

    parts =
      case task.assignees do
        [] -> parts
        assignees -> parts ++ Enum.map(assignees, &"@#{&1}")
      end

    parts =
      case task.pr do
        nil -> parts
        pr -> parts ++ ["#pr:#{pr}"]
      end

    parts =
      case task.attachments do
        [] -> parts
        attachments -> parts ++ Enum.map(attachments, &"^#{&1}")
      end

    task_line = "- [#{task.id}] #{Enum.join(parts, " ")}"

    case task.description do
      "" ->
        task_line

      desc ->
        desc_lines = desc |> String.split("\n") |> Enum.map_join("\n", &"  #{&1}")
        task_line <> "\n" <> desc_lines
    end
  end
end
