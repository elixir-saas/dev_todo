defmodule DevTodo.Web.IndexLive do
  @moduledoc false

  use DevTodo.Web, :live_view

  alias DevTodo.Task

  def render(assigns) do
    ~H"""
    <.layout flash={@flash}>
      <div class="bg-base-200 flex min-h-0 flex-1 flex-col">
        <div class="flex flex-col gap-2 px-4 pt-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div class="mb-3">
            <h1 class="text-xl font-semibold">DevTodo</h1>
            <p class="text-base-content/40 hidden text-sm sm:block">
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
              phx-click={JS.push("open_modal")}
            >
              <.icon name="hero-plus-micro" class="size-4" />
              <span class="hidden sm:inline">Add task</span>
            </button>
            <.theme_toggle />
          </div>
        </div>

        <.label_filter
          :if={@all_labels != []}
          all_labels={@all_labels}
          filter_labels={@filter_labels}
          label_colors={@label_colors}
        />

        <.parse_warnings :if={@warnings != []} warnings={@warnings} />

        <%= if @live_action == :board do %>
          <.board
            tasks={@filtered_tasks}
            statuses={@statuses}
            prefix={@prefix}
            repo_url={@repo_url}
            label_colors={@label_colors}
          />
        <% else %>
          <.list_view
            tasks={@filtered_tasks}
            statuses={@statuses}
            prefix={@prefix}
            repo_url={@repo_url}
            label_colors={@label_colors}
          />
        <% end %>
      </div>

      <.modal :if={@modal_task} id="task-modal" on_cancel={JS.push("close_modal")}>
        <div class="space-y-4">
          <div :if={@modal_task.id} class="flex items-start gap-3">
            <.task_status_icon status={@modal_task.status} />
            <div class="flex-1">
              <h3 class="text-xl font-semibold">{@modal_task.title}</h3>
              <span class="text-base-content/40 font-mono text-sm">
                {@prefix}-{@modal_task.id}
              </span>
            </div>
          </div>
          <h3 :if={!@modal_task.id} class="text-xl font-semibold">Add Task</h3>

          <form phx-submit="save_task" phx-change="validate_task" class="space-y-4">
            <div class="flex flex-col gap-1">
              <label class="text-base font-medium">Title</label>
              <input
                type="text"
                name="title"
                value={@modal_task.title}
                placeholder="What needs to be done?"
                class="input input-bordered w-full"
                required
              />
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-base font-medium">Status</label>
              <select name="status" class="select select-bordered w-full">
                <option
                  :for={status <- @statuses}
                  value={status}
                  selected={@modal_task.status == status}
                >
                  {status_name(status)}
                </option>
              </select>
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-base font-medium">Assignees</label>
              <input
                type="text"
                name="assignees"
                value={Enum.map_join(@modal_task.assignees, " ", &"@#{&1}")}
                placeholder="@user1 @user2"
                class={["input input-bordered w-full", @assignees_error && "input-error"]}
              />
              <p :if={@assignees_error} class="text-error text-sm">{@assignees_error}</p>
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-base font-medium">Labels</label>
              <input
                type="text"
                name="labels"
                value={Enum.join(@modal_task.labels, ", ")}
                placeholder="bug, feature, docs"
                class="input input-bordered w-full"
              />
              <p class="text-base-content/40 text-sm">Comma-separated label names</p>
            </div>
            <div class="flex flex-col gap-1">
              <label class="text-base font-medium">Description</label>
              <textarea
                name="description"
                class="textarea textarea-bordered min-h-[6rem] w-full text-base"
                placeholder="Add notes..."
              >{@modal_task.description}</textarea>
            </div>
            <div class={["flex pt-2", @modal_task.id && "items-center justify-between", !@modal_task.id && "justify-end"]}>
              <button
                :if={@modal_task.id}
                type="button"
                class="btn btn-error btn-sm btn-outline"
                phx-click="delete_task"
                phx-value-id={@modal_task.id}
                data-confirm="Delete this task?"
              >
                <.icon name="hero-trash-micro" class="size-4" /> Delete
              </button>
              <div class="flex gap-2">
                <button
                  type="button"
                  class="btn"
                  phx-click={hide_modal("task-modal") |> JS.push("close_modal")}
                >
                  Cancel
                </button>
                <.button type="submit">{if @modal_task.id, do: "Save", else: "Create Task"}</.button>
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

    tasks = DevTodo.list_tasks()

    socket =
      socket
      |> assign(:page_title, "Tasks")
      |> assign(:board_path, dev_todo_path(socket))
      |> assign(:list_path, dev_todo_path(socket, "/list"))
      |> assign(:statuses, DevTodo.list_statuses())
      |> assign(:prefix, DevTodo.prefix())
      |> assign(:tasks, tasks)
      |> assign(:label_colors, DevTodo.label_colors())
      |> assign(:filter_labels, MapSet.new())
      |> assign(:repo_url, DevTodo.repo_url())
      |> assign(:warnings, DevTodo.warnings())
      |> assign(:modal_task, nil)
      |> assign(:assignees_error, nil)
      |> assign_derived(tasks)

    {:ok, socket, layout: false}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def handle_event("open_modal", params, socket) do
    default_status =
      case params do
        %{"status" => status} -> String.to_existing_atom(status)
        _ -> :todo
      end

    task = %Task{status: default_status, assignees: [], labels: [], attachments: []}
    {:noreply, socket |> assign(:modal_task, task) |> assign(:assignees_error, nil)}
  end

  def handle_event("open_task", %{"id" => id}, socket) do
    task = DevTodo.get_task(id)
    {:noreply, socket |> assign(:modal_task, task) |> assign(:assignees_error, nil)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :modal_task, nil)}
  end

  def handle_event("save_task", params, socket) do
    %{
      "title" => title,
      "status" => status,
      "assignees" => assignees_str,
      "labels" => labels_str,
      "description" => description
    } = params

    case validate_assignees(assignees_str) do
      nil ->
        assignees = parse_assignees(assignees_str)
        labels = parse_labels(labels_str)
        target_status = String.to_atom(status)

        case socket.assigns.modal_task do
          %Task{id: nil} ->
            case DevTodo.create_task(%{
                   title: String.trim(title),
                   status: target_status,
                   assignees: assignees,
                   labels: labels,
                   description: String.trim(description)
                 }) do
              {:ok, _task} ->
                {:noreply, socket |> assign(:modal_task, nil) |> assign(:assignees_error, nil)}

              {:error, _reason} ->
                {:noreply, put_flash(socket, :error, "Failed to create task")}
            end

          %Task{id: id, status: current_status} ->
            if target_status != current_status do
              DevTodo.move_task(id, target_status, nil, nil)
            end

            DevTodo.update_task(id, %{
              title: String.trim(title),
              description: String.trim(description),
              assignees: assignees,
              labels: labels
            })

            {:noreply, assign(socket, :modal_task, nil)}
        end

      error ->
        {:noreply, assign(socket, :assignees_error, error)}
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

  def handle_event("delete_task", %{"id" => id}, socket) do
    DevTodo.delete_task(id)
    {:noreply, assign(socket, :modal_task, nil)}
  end

  def handle_event("toggle_label", %{"label" => label}, socket) do
    filter_labels = socket.assigns.filter_labels

    filter_labels =
      if MapSet.member?(filter_labels, label),
        do: MapSet.delete(filter_labels, label),
        else: MapSet.put(filter_labels, label)

    socket =
      socket
      |> assign(:filter_labels, filter_labels)
      |> assign_derived(socket.assigns.tasks)

    {:noreply, socket}
  end

  def handle_event("clear_label_filter", _params, socket) do
    socket =
      socket
      |> assign(:filter_labels, MapSet.new())
      |> assign_derived(socket.assigns.tasks)

    {:noreply, socket}
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

  defp parse_labels(str) do
    str
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp assign_derived(socket, tasks) do
    all_labels =
      tasks
      |> Map.values()
      |> List.flatten()
      |> Enum.flat_map(& &1.labels)
      |> Enum.uniq()
      |> Enum.sort()

    filter_labels = socket.assigns.filter_labels

    filtered_tasks =
      if MapSet.size(filter_labels) == 0 do
        tasks
      else
        Map.new(tasks, fn {status, task_list} ->
          {status,
           Enum.filter(task_list, fn t ->
             Enum.any?(t.labels, &MapSet.member?(filter_labels, &1))
           end)}
        end)
      end

    socket
    |> assign(:all_labels, all_labels)
    |> assign(:filtered_tasks, filtered_tasks)
  end

  def handle_info({:tasks_updated, prefix, statuses, tasks, label_colors, warnings}, socket) do
    # If the task modal is open, refresh the selected task from new data
    modal_task =
      case socket.assigns.modal_task do
        %Task{id: id} when not is_nil(id) ->
          tasks |> Map.values() |> List.flatten() |> Enum.find(&(&1.id == id))

        other ->
          other
      end

    {:noreply,
     socket
     |> assign(:prefix, prefix)
     |> assign(:statuses, statuses)
     |> assign(:tasks, tasks)
     |> assign(:label_colors, label_colors)
     |> assign(:warnings, warnings)
     |> assign(:modal_task, modal_task)
     |> assign_derived(tasks)}
  end
end
