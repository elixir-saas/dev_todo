defmodule DevTodo.Web.IndexLive do
  @moduledoc false

  use DevTodo.Web, :live_view

  def render(assigns) do
    ~H"""
    <.layout flash={@flash}>
      <div class="bg-base-200 flex min-h-0 flex-1 flex-col">
        <div class="flex flex-col gap-2 px-4 pt-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div class="mb-3">
            <h1 class="text-lg font-semibold">DevTodo</h1>
            <p class="text-base-content/40 hidden text-xs sm:block">
              Changes sync both ways with TODO.md — edit here, in your editor, or let an AI agent manage your tasks.
            </p>
          </div>
          <div class="flex items-center gap-2">
            <div class="join">
              <.link
                patch={@board_path}
                class={["join-item btn btn-sm", @live_action == :board && "btn-active"]}
              >
                <.icon name="hero-view-columns-micro" class="size-4" />
              </.link>
              <.link
                patch={@list_path}
                class={["join-item btn btn-sm", @live_action == :list && "btn-active"]}
              >
                <.icon name="hero-list-bullet-micro" class="size-4" />
              </.link>
            </div>
            <button
              class="btn btn-sm btn-primary"
              phx-click={JS.push("open_add_modal")}
            >
              <.icon name="hero-plus-micro" class="size-4" />
              <span class="hidden sm:inline">Add task</span>
            </button>
            <.theme_toggle />
          </div>
        </div>

        <.parse_warnings :if={@warnings != []} warnings={@warnings} />

        <%= if @live_action == :board do %>
          <.board
            tasks={@tasks}
            statuses={@statuses}
            prefix={@prefix}
            repo_url={@repo_url}
          />
        <% else %>
          <.list_view
            tasks={@tasks}
            statuses={@statuses}
            prefix={@prefix}
            repo_url={@repo_url}
          />
        <% end %>
      </div>

      <.modal :if={@show_add_modal} id="add-task-modal" on_cancel={JS.push("close_add_modal")}>
        <h3 class="mb-4 text-lg font-semibold">Add Task</h3>
        <form phx-submit="create_task" phx-change="validate_task" class="space-y-4">
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium">Title</label>
            <input
              type="text"
              name="title"
              placeholder="What needs to be done?"
              class="input input-bordered w-full"
              required
            />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium">Status</label>
            <select name="status" class="select select-bordered w-full">
              <option
                :for={status <- @statuses}
                value={status}
                selected={status == @add_default_status}
              >
                {status_name(status)}
              </option>
            </select>
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium">Assignees</label>
            <input
              type="text"
              name="assignees"
              placeholder="@user1 @user2"
              class={["input input-bordered w-full", @assignees_error && "input-error"]}
            />
            <p :if={@assignees_error} class="text-error text-xs">{@assignees_error}</p>
          </div>
          <div class="flex justify-end gap-2 pt-2">
            <button
              type="button"
              class="btn"
              phx-click={hide_modal("add-task-modal") |> JS.push("close_add_modal")}
            >
              Cancel
            </button>
            <.button type="submit">Create Task</.button>
          </div>
        </form>
      </.modal>

      <.modal :if={@selected_task} id="task-modal" on_cancel={JS.push("close_task")}>
        <div class="space-y-4">
          <div class="flex items-start gap-3">
            <.task_status_icon status={@selected_task.status} />
            <div class="flex-1">
              <h3 class="text-lg font-semibold">{@selected_task.title}</h3>
              <span class="text-base-content/40 font-mono text-xs">
                {@prefix}-{@selected_task.id}
              </span>
            </div>
          </div>

          <form phx-submit="save_task" class="space-y-4">
            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium">Title</label>
              <input
                type="text"
                name="title"
                value={@selected_task.title}
                class="input input-bordered w-full"
                required
              />
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium">Status</label>
              <select name="status" class="select select-bordered w-full">
                <option
                  :for={status <- @statuses}
                  value={status}
                  selected={@selected_task.status == status}
                >
                  {status_name(status)}
                </option>
              </select>
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium">Assignees</label>
              <input
                type="text"
                name="assignees"
                value={Enum.map_join(@selected_task.assignees, " ", &"@#{&1}")}
                placeholder="@user1 @user2"
                class={["input input-bordered w-full", @task_assignees_error && "input-error"]}
              />
              <p :if={@task_assignees_error} class="text-error text-xs">{@task_assignees_error}</p>
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-sm font-medium">Description</label>
              <textarea
                name="description"
                class="textarea textarea-bordered min-h-[6rem] w-full text-sm"
                placeholder="Add notes..."
              >{@selected_task.description}</textarea>
            </div>
            <div class="flex items-center justify-between pt-2">
              <button
                type="button"
                class="btn btn-error btn-sm btn-outline"
                phx-click="delete_task"
                phx-value-id={@selected_task.id}
                data-confirm="Delete this task?"
              >
                <.icon name="hero-trash-micro" class="size-4" /> Delete
              </button>
              <div class="flex gap-2">
                <button
                  type="button"
                  class="btn"
                  phx-click={hide_modal("task-modal") |> JS.push("close_task")}
                >
                  Cancel
                </button>
                <.button type="submit">Save</.button>
              </div>
            </div>
          </form>
        </div>
      </.modal>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket), do: DevTodo.subscribe()

    socket =
      socket
      |> assign(:page_title, "Tasks")
      |> assign(:board_path, dev_todo_path(socket))
      |> assign(:list_path, dev_todo_path(socket, "/list"))
      |> assign(:statuses, DevTodo.list_statuses())
      |> assign(:prefix, DevTodo.prefix())
      |> assign(:tasks, DevTodo.list_tasks())
      |> assign(:repo_url, DevTodo.repo_url())
      |> assign(:warnings, DevTodo.warnings())
      |> assign(:show_add_modal, false)
      |> assign(:add_default_status, :todo)
      |> assign(:assignees_error, nil)
      |> assign(:selected_task, nil)
      |> assign(:task_assignees_error, nil)

    {:ok, socket, layout: false}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("open_add_modal", params, socket) do
    default_status =
      case params do
        %{"status" => status} -> String.to_existing_atom(status)
        _ -> :todo
      end

    {:noreply,
     socket |> assign(:show_add_modal, true) |> assign(:add_default_status, default_status)}
  end

  def handle_event("close_add_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_modal, false)}
  end

  def handle_event("open_task", %{"id" => id}, socket) do
    task = DevTodo.get_task(id)
    {:noreply, socket |> assign(:selected_task, task) |> assign(:task_assignees_error, nil)}
  end

  def handle_event("close_task", _params, socket) do
    {:noreply, assign(socket, :selected_task, nil)}
  end

  def handle_event("save_task", params, socket) do
    %{
      "title" => title,
      "status" => status,
      "assignees" => assignees_str,
      "description" => description
    } = params

    task = socket.assigns.selected_task

    case validate_assignees(assignees_str) do
      nil ->
        assignees = parse_assignees(assignees_str)
        target_status = String.to_atom(status)

        if target_status != task.status do
          DevTodo.move_task(task.id, target_status, nil, nil)
        end

        DevTodo.update_task(task.id, %{
          title: String.trim(title),
          description: String.trim(description),
          assignees: assignees
        })

        {:noreply, assign(socket, :selected_task, nil)}

      error ->
        {:noreply, assign(socket, :task_assignees_error, error)}
    end
  end

  def handle_event("move_task", %{"group_id" => status, "item_id" => item_id} = params, socket) do
    DevTodo.move_task(
      item_id,
      status,
      params["prev_item_id"],
      params["next_item_id"]
    )

    {:noreply, socket}
  end

  def handle_event("validate_task", %{"assignees" => assignees_str}, socket) do
    {:noreply, assign(socket, :assignees_error, validate_assignees(assignees_str))}
  end

  def handle_event(
        "create_task",
        %{"title" => title, "status" => status, "assignees" => assignees_str},
        socket
      ) do
    case validate_assignees(assignees_str) do
      nil ->
        assignees = parse_assignees(assignees_str)

        case DevTodo.create_task(%{
               title: String.trim(title),
               status: String.to_atom(status),
               assignees: assignees
             }) do
          {:ok, _task} ->
            {:noreply, socket |> assign(:show_add_modal, false) |> assign(:assignees_error, nil)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to create task")}
        end

      error ->
        {:noreply, assign(socket, :assignees_error, error)}
    end
  end

  def handle_event("delete_task", %{"id" => id}, socket) do
    DevTodo.delete_task(id)
    {:noreply, assign(socket, :selected_task, nil)}
  end

  defp validate_assignees(""), do: nil

  defp validate_assignees(str) do
    words = String.split(str, ~r/\s+/, trim: true)

    cond do
      Enum.all?(words, &String.starts_with?(&1, "@")) -> nil
      true -> "Each assignee must start with @ (e.g. @alice @bob)"
    end
  end

  defp parse_assignees(str) do
    str
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.trim_leading(&1, "@"))
    |> Enum.reject(&(&1 == ""))
  end

  def handle_info({:tasks_updated, prefix, statuses, tasks, warnings}, socket) do
    # If the task modal is open, refresh the selected task from new data
    selected_task =
      case socket.assigns.selected_task do
        nil ->
          nil

        %{id: id} ->
          tasks |> Map.values() |> List.flatten() |> Enum.find(&(&1.id == id))
      end

    {:noreply,
     socket
     |> assign(:prefix, prefix)
     |> assign(:statuses, statuses)
     |> assign(:tasks, tasks)
     |> assign(:warnings, warnings)
     |> assign(:selected_task, selected_task)}
  end
end
