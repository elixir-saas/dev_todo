defmodule DevTodo.ParserTest do
  use ExUnit.Case, async: true

  alias DevTodo.{Parser, Task}

  @header """
  <!--
  TODO.md — Project Task Board

  - Prefix: DEV

  Rules for AI agents editing this file:
  -->\
  """

  @full_doc """
  #{@header}

  ## In Progress

  - [1] Add OAuth login flow @justin #pr:42
  - [2] Add user avatar upload @claude

  ## Todo

  - [3] Redesign email templates @justin
  - [4] Improve dark mode contrast

  ## Backlog

  ## Done

  - [5] Fix mobile navigation @claude
  - [6] Set up CI pipeline @justin #pr:38
  """

  describe "parse/1" do
    test "parses statuses in order from ## headings" do
      {statuses, _tasks, _, _} = Parser.parse(@full_doc)
      assert statuses == [:in_progress, :todo, :backlog, :done]
    end

    test "parses tasks into correct status buckets" do
      {_statuses, tasks, _, _} = Parser.parse(@full_doc)

      assert length(tasks[:in_progress]) == 2
      assert length(tasks[:todo]) == 2
      assert tasks[:backlog] == []
      assert length(tasks[:done]) == 2
    end

    test "parses task id as integer" do
      {_statuses, tasks, _, _} = Parser.parse(@full_doc)
      task = hd(tasks[:in_progress])
      assert task.id == 1
      assert is_integer(task.id)
    end

    test "parses task title" do
      {_statuses, tasks, _, _} = Parser.parse(@full_doc)
      task = hd(tasks[:in_progress])
      assert task.title == "Add OAuth login flow"
    end

    test "parses assignees" do
      {_statuses, tasks, _, _} = Parser.parse(@full_doc)
      task = hd(tasks[:in_progress])
      assert task.assignees == ["justin"]
    end

    test "parses PR number" do
      {_statuses, tasks, _, _} = Parser.parse(@full_doc)
      task = hd(tasks[:in_progress])
      assert task.pr == 42
    end

    test "parses task with no assignees or PR" do
      {_statuses, tasks, _, _} = Parser.parse(@full_doc)
      task = Enum.find(tasks[:todo], &(&1.id == 4))
      assert task.title == "Improve dark mode contrast"
      assert task.assignees == []
      assert task.pr == nil
    end

    test "parses attachments" do
      doc = """
      ## Todo

      - [1] Review design ^mockups/v2.png ^docs/spec.md
      """

      {_statuses, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.attachments == ["mockups/v2.png", "docs/spec.md"]
    end

    test "sets position based on order within section" do
      {_statuses, tasks, _, _} = Parser.parse(@full_doc)
      [first, second] = tasks[:in_progress]
      assert first.position == 0
      assert second.position == 1
    end

    test "sets status on each task" do
      {_statuses, tasks, _, _} = Parser.parse(@full_doc)
      assert hd(tasks[:in_progress]).status == :in_progress
      assert hd(tasks[:todo]).status == :todo
      assert hd(tasks[:done]).status == :done
    end

    test "ignores non-task lines" do
      doc = """
      ## Todo

      Some random text here.

      - [1] Real task

      Another line.
      """

      {_statuses, tasks, _, _} = Parser.parse(doc)
      assert length(tasks[:todo]) == 1
      assert hd(tasks[:todo]).title == "Real task"
    end

    test "ignores content before first heading" do
      doc = """
      <!-- This is a comment -->

      Some preamble text.

      - [99] Not a real task

      ## Todo

      - [1] Actual task
      """

      {statuses, tasks, _, _} = Parser.parse(doc)
      assert statuses == [:todo]
      assert length(tasks[:todo]) == 1
      assert hd(tasks[:todo]).id == 1
    end

    test "handles empty document" do
      {statuses, tasks, _, _} = Parser.parse("")
      assert statuses == []
      assert tasks == %{}
    end

    test "handles section with no tasks" do
      doc = """
      ## Backlog

      """

      {statuses, tasks, _, _} = Parser.parse(doc)
      assert statuses == [:backlog]
      assert tasks[:backlog] == []
    end

    test "handles multiple assignees" do
      doc = """
      ## Todo

      - [1] Pair on feature @alice @bob
      """

      {_statuses, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.assignees == ["alice", "bob"]
    end

    test "handles hyphenated assignee names" do
      doc = """
      ## Todo

      - [1] Fix bug @mary-jane
      """

      {_statuses, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.assignees == ["mary-jane"]
    end

    test "handles custom status headings" do
      doc = """
      ## Code Review

      - [1] Review PR

      ## QA Testing

      - [2] Test feature
      """

      {statuses, tasks, _, _} = Parser.parse(doc)
      assert statuses == [:code_review, :qa_testing]
      assert hd(tasks[:code_review]).title == "Review PR"
      assert hd(tasks[:qa_testing]).title == "Test feature"
    end

    test "handles task with all metadata" do
      doc = """
      ## Todo

      - [1] Build feature @alice @bob #pr:99 #label:bug #label:urgent ^designs/mock.png ^specs/req.md
      """

      {_statuses, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.id == 1
      assert task.title == "Build feature"
      assert task.assignees == ["alice", "bob"]
      assert task.pr == 99
      assert task.labels == ["bug", "urgent"]
      assert task.attachments == ["designs/mock.png", "specs/req.md"]
    end

    test "strips metadata from title" do
      doc = """
      ## Todo

      - [1] My task @user #pr:5 #label:feature ^file.txt
      """

      {_statuses, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.title == "My task"
    end

    test "parses labels" do
      doc = """
      ## Todo

      - [1] Fix login bug #label:bug #label:urgent
      """

      {_statuses, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.labels == ["bug", "urgent"]
    end

    test "parses task with no labels" do
      doc = """
      ## Todo

      - [1] Simple task
      """

      {_statuses, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.labels == []
    end

    test "parses labels with hyphens and numbers" do
      doc = """
      ## Todo

      - [1] Task #label:high-priority #label:v2
      """

      {_statuses, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.labels == ["high-priority", "v2"]
    end
  end

  describe "warnings and raw lines" do
    test "produces no warnings for valid document" do
      {_, _, _, warnings} = Parser.parse(@full_doc)
      assert warnings == []
    end

    test "produces no raw lines for valid document" do
      {_, _, raw_lines, _} = Parser.parse(@full_doc)
      assert raw_lines == %{}
    end

    test "warns on malformed task lines (starts with dash but no valid ID)" do
      doc = """
      ## Todo

      - [1] Valid task
      - Fix the bug
      - Another broken line
      """

      {_, tasks, _, warnings} = Parser.parse(doc)
      assert length(tasks[:todo]) == 1
      assert length(warnings) == 2
      assert Enum.all?(warnings, fn {status, _} -> status == :todo end)
    end

    test "warning includes the malformed line content" do
      doc = """
      ## In Progress

      - oops no brackets
      """

      {_, _, _, [{status, line}]} = Parser.parse(doc)
      assert status == :in_progress
      assert line =~ "oops no brackets"
    end

    test "captures non-task lines as raw_lines" do
      doc = """
      ## Todo

      - [1] Valid task
      Some note about the tasks above
      """

      {_, _, raw_lines, _} = Parser.parse(doc)
      assert ["Some note about the tasks above"] = raw_lines[:todo]
    end

    test "raw_lines are per-section" do
      doc = """
      ## Todo

      - [1] Task one
      Note in todo

      ## Done

      - [2] Task two
      Note in done
      """

      {_, _, raw_lines, _} = Parser.parse(doc)
      assert ["Note in todo"] = raw_lines[:todo]
      assert ["Note in done"] = raw_lines[:done]
    end

    test "malformed task lines are both warnings and raw_lines" do
      doc = """
      ## Todo

      - [1] Good task
      - bad task no id
      """

      {_, _, raw_lines, warnings} = Parser.parse(doc)
      assert length(warnings) == 1
      assert ["- bad task no id"] = raw_lines[:todo]
    end

    test "non-dash lines are raw_lines but not warnings" do
      doc = """
      ## Todo

      - [1] Good task
      Just a comment
      """

      {_, _, raw_lines, warnings} = Parser.parse(doc)
      assert warnings == []
      assert ["Just a comment"] = raw_lines[:todo]
    end

    test "content before first heading produces no warnings" do
      doc = """
      Some preamble
      - not a task

      ## Todo

      - [1] Real task
      """

      {_, _, _, warnings} = Parser.parse(doc)
      assert warnings == []
    end
  end

  describe "serialize round-trip with raw lines" do
    test "round-trips through parse and serialize" do
      {statuses, tasks, raw_lines, _} = Parser.parse(@full_doc)
      serialized = Parser.serialize(statuses, tasks, @header, raw_lines)
      {statuses2, tasks2, _, _} = Parser.parse(serialized)

      assert statuses == statuses2

      for status <- statuses do
        original = Map.get(tasks, status, [])
        reparsed = Map.get(tasks2, status, [])
        assert length(original) == length(reparsed)

        for {orig, re} <- Enum.zip(original, reparsed) do
          assert orig.id == re.id
          assert orig.title == re.title
          assert orig.assignees == re.assignees
          assert orig.pr == re.pr
          assert orig.attachments == re.attachments
        end
      end
    end

    test "preserves unrecognized lines through serialize round-trip" do
      doc = """
      ## Todo

      - [1] Valid task
      Some random note
      - broken task line
      """

      {statuses, tasks, raw_lines, _} = Parser.parse(doc)
      serialized = Parser.serialize(statuses, tasks, "", raw_lines)
      {_, _, raw_lines2, warnings2} = Parser.parse(serialized)

      assert ["Some random note", "- broken task line"] = raw_lines2[:todo]
      assert length(warnings2) == 1
    end

    test "serializes task with all fields" do
      tasks = %{
        todo: [
          %Task{
            id: 1,
            title: "Build feature",
            status: :todo,
            assignees: ["alice", "bob"],
            pr: 42,
            labels: ["bug", "urgent"],
            attachments: ["mock.png"],
            position: 0
          }
        ]
      }

      result = Parser.serialize([:todo], tasks, "# Header")
      assert result =~ "- [1] Build feature @alice @bob #pr:42 #label:bug #label:urgent ^mock.png"
    end

    test "serializes task with no metadata" do
      tasks = %{
        todo: [
          %Task{
            id: 1,
            title: "Simple task",
            status: :todo,
            assignees: [],
            pr: nil,
            labels: [],
            attachments: [],
            position: 0
          }
        ]
      }

      result = Parser.serialize([:todo], tasks, "# Header")
      assert result =~ "- [1] Simple task\n"
    end

    test "serializes labels" do
      tasks = %{
        todo: [
          %Task{
            id: 1,
            title: "Labeled task",
            status: :todo,
            assignees: [],
            pr: nil,
            labels: ["feature", "v2"],
            attachments: [],
            position: 0
          }
        ]
      }

      result = Parser.serialize([:todo], tasks, "# Header")
      assert result =~ "- [1] Labeled task #label:feature #label:v2"
    end

    test "serializes empty sections" do
      result = Parser.serialize([:backlog], %{backlog: []}, "# Header")
      assert result =~ "## Backlog\n"
    end

    test "preserves section order" do
      statuses = [:done, :in_progress, :todo]
      tasks = Map.new(statuses, &{&1, []})
      result = Parser.serialize(statuses, tasks, "# Header")

      done_pos = :binary.match(result, "## Done") |> elem(0)
      in_progress_pos = :binary.match(result, "## In Progress") |> elem(0)
      todo_pos = :binary.match(result, "## Todo") |> elem(0)

      assert done_pos < in_progress_pos
      assert in_progress_pos < todo_pos
    end

    test "preserves header" do
      result = Parser.serialize([:todo], %{todo: []}, @header)
      assert String.starts_with?(result, "<!--")
    end
  end

  describe "descriptions" do
    test "parses single-line description" do
      doc = """
      ## Todo

      - [1] Task with desc
        This is the description
      """

      {_, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.description == "This is the description"
    end

    test "parses multi-line description" do
      doc = """
      ## Todo

      - [1] Task with desc
        Line one
        Line two
        Line three
      """

      {_, tasks, _, _} = Parser.parse(doc)
      task = hd(tasks[:todo])
      assert task.description == "Line one\nLine two\nLine three"
    end

    test "description belongs to preceding task only" do
      doc = """
      ## Todo

      - [1] First task
        First desc
      - [2] Second task
      """

      {_, tasks, _, _} = Parser.parse(doc)
      assert hd(tasks[:todo]).description == "First desc"
      assert List.last(tasks[:todo]).description == ""
    end

    test "serializes description as indented lines" do
      tasks = %{
        todo: [
          %Task{
            id: 1,
            title: "Described task",
            status: :todo,
            description: "Line one\nLine two",
            assignees: [],
            pr: nil,
            attachments: [],
            position: 0
          }
        ]
      }

      result = Parser.serialize([:todo], tasks, "# Header")
      assert result =~ "- [1] Described task\n  Line one\n  Line two"
    end

    test "round-trips descriptions" do
      doc = """
      ## Todo

      - [1] My task
        Description line one
        Description line two
      """

      {statuses, tasks, _, _} = Parser.parse(doc)
      serialized = Parser.serialize(statuses, tasks, "")
      {_, tasks2, _, _} = Parser.parse(serialized)

      assert hd(tasks2[:todo]).description == "Description line one\nDescription line two"
    end

    test "round-trips labels" do
      doc = """
      ## Todo

      - [1] My task #label:bug #label:feature
      """

      {statuses, tasks, _, _} = Parser.parse(doc)
      serialized = Parser.serialize(statuses, tasks, "")
      {_, tasks2, _, _} = Parser.parse(serialized)

      assert hd(tasks2[:todo]).labels == ["bug", "feature"]
    end
  end

  describe "has_duplicate_ids?/1" do
    test "returns false when all IDs are unique" do
      tasks = %{
        todo: [%Task{id: 1, title: "A", status: :todo, position: 0}],
        done: [%Task{id: 2, title: "B", status: :done, position: 0}]
      }

      refute Parser.has_duplicate_ids?(tasks)
    end

    test "returns true when IDs are duplicated within a status" do
      tasks = %{
        todo: [
          %Task{id: 1, title: "A", status: :todo, position: 0},
          %Task{id: 1, title: "B", status: :todo, position: 1}
        ]
      }

      assert Parser.has_duplicate_ids?(tasks)
    end

    test "returns true when IDs are duplicated across statuses" do
      tasks = %{
        todo: [%Task{id: 1, title: "A", status: :todo, position: 0}],
        done: [%Task{id: 1, title: "B", status: :done, position: 0}]
      }

      assert Parser.has_duplicate_ids?(tasks)
    end

    test "returns false for empty tasks" do
      refute Parser.has_duplicate_ids?(%{})
    end
  end

  describe "heading_to_status/1" do
    test "converts simple heading" do
      assert Parser.heading_to_status("Todo") == :todo
    end

    test "converts multi-word heading" do
      assert Parser.heading_to_status("In Progress") == :in_progress
    end

    test "converts heading with extra spaces" do
      assert Parser.heading_to_status("  In Progress  ") == :in_progress
    end

    test "handles mixed case" do
      assert Parser.heading_to_status("CODE REVIEW") == :code_review
    end
  end

  describe "status_to_heading/1" do
    test "converts simple status" do
      assert Parser.status_to_heading(:todo) == "Todo"
    end

    test "converts multi-word status" do
      assert Parser.status_to_heading(:in_progress) == "In Progress"
    end

    test "capitalizes each word" do
      assert Parser.status_to_heading(:code_review) == "Code Review"
    end
  end
end
