defmodule DevTodo do
  @moduledoc """
  A file-backed Kanban board for Elixir projects.

  TODO.md is the source of truth. A web UI provides board + list views.
  A file watcher updates the UI in realtime when the file is edited externally.

  ## Setup

  Add to your dependencies:

      {:dev_todo, "~> 0.1.0", only: :dev}

  Configure in your `config/dev.exs`:

      config :dev_todo,
        pubsub: MyApp.PubSub

  Add to your supervision tree in `application.ex`:

      children = [
        # ... your other children ...
        DevTodo.Supervisor,
        MyAppWeb.Endpoint
      ]

  Add to your router:

      import DevTodo.Router

      scope "/dev" do
        pipe_through :browser
        dev_todo "/todo"
      end

  ## Configuration

  - `:pubsub` (required) — your app's PubSub module
  - `:todo_path` — path to TODO.md (default: `"TODO.md"`)
  """

  alias DevTodo.Server

  @doc "Returns tasks grouped by status as `%{status => [%DevTodo.Task{}]}`."
  defdelegate list_tasks, to: Server

  @doc "Returns the task with the given `id`, or `nil` if not found."
  defdelegate get_task(id), to: Server

  @doc """
  Creates a new task. Returns `{:ok, task}` or `{:error, reason}`.

  Attrs: `:title` (required), `:status`, `:assignees`, `:pr`, `:attachments`.
  """
  defdelegate create_task(attrs), to: Server

  @doc """
  Updates a task by `id`. Returns `{:ok, task}` or `{:error, reason}`.

  Only the keys present in `attrs` are updated.
  """
  defdelegate update_task(id, attrs), to: Server

  @doc "Deletes the task with the given `id`."
  defdelegate delete_task(id), to: Server

  @doc """
  Moves a task to `target_status`, inserting between `prev_id` and `next_id`.

  Pass `nil` for `prev_id`/`next_id` to insert at the beginning/end.
  """
  defdelegate move_task(task_id, target_status, prev_id, next_id), to: Server

  @doc "Returns the ordered list of status atoms (e.g., `[:in_progress, :todo, :backlog, :done]`)."
  defdelegate list_statuses, to: Server

  @doc "Returns the task ID prefix (e.g., `\"DEV\"`)."
  defdelegate prefix, to: Server

  @doc "Returns a list of `{status, line}` tuples for lines that couldn't be parsed."
  defdelegate warnings, to: Server

  @doc "Returns the label color map `%{\"bug\" => \"red\", ...}` from the TODO.md header."
  defdelegate label_colors, to: Server

  @doc "Subscribes the calling process to task update broadcasts via PubSub."
  defdelegate subscribe, to: Server

  @doc "Returns the GitHub repository URL derived from the git remote, or `nil`."
  defdelegate repo_url, to: Server

  @doc false
  def config(key, default \\ nil) do
    Application.get_env(:dev_todo, key, default)
  end

  @doc false
  def config!(key) do
    Application.fetch_env!(:dev_todo, key)
  end
end
