defmodule DevTodo.Web.Components do
  @moduledoc false

  use DevTodo.Web, :html

  alias DevTodo.Parser

  attr(:flash, :map, required: true)
  slot(:inner_block, required: true)

  def layout(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
    {render_slot(@inner_block)}
    """
  end

  attr(:id, :string, required: true)
  attr(:on_cancel, JS, default: %JS{})
  slot(:inner_block, required: true)

  def modal(assigns) do
    assigns =
      assign(assigns, :cancel_js, %JS{
        ops: JS.exec("data-hide", to: "##{assigns.id}").ops ++ assigns.on_cancel.ops
      })

    ~H"""
    <div
      id={@id}
      phx-mounted={JS.exec("data-show", to: "##{@id}")}
      phx-remove={JS.exec("data-hide", to: "##{@id}")}
      data-show={
        JS.show(
          to: "##{@id}-backdrop",
          transition: {"ease-out duration-200", "opacity-0", "opacity-100"}
        )
        |> JS.show(
          to: "##{@id}-content",
          transition: {"ease-out duration-200", "opacity-0 scale-95", "opacity-100 scale-100"}
        )
        |> JS.focus_first(to: "##{@id}-content")
      }
      data-hide={
        JS.hide(
          to: "##{@id}-backdrop",
          transition: {"ease-in duration-100", "opacity-100", "opacity-0"}
        )
        |> JS.hide(
          to: "##{@id}-content",
          transition: {"ease-in duration-100", "opacity-100 scale-100", "opacity-0 scale-95"}
        )
        |> JS.hide(to: "##{@id}")
      }
      data-cancel={@cancel_js}
      class="relative z-50"
    >
      <div
        id={"#{@id}-backdrop"}
        class="bg-black/50 fixed inset-0 hidden transition-opacity"
        aria-hidden="true"
      />
      <div class="fixed inset-0 overflow-y-auto" role="dialog" aria-modal="true">
        <div class="flex min-h-full items-end justify-center p-2 sm:items-center sm:p-4">
          <div
            id={"#{@id}-content"}
            class="bg-base-100 ring-base-300 hidden w-full max-w-lg rounded-t-lg p-4 shadow-xl ring-1 transition sm:rounded-lg sm:p-6"
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
          >
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  def show_modal(js \\ %JS{}, id) do
    JS.show(js, to: "##{id}")
    |> JS.exec("data-show", to: "##{id}")
  end

  def hide_modal(js \\ %JS{}, id) do
    JS.exec(js, "data-hide", to: "##{id}")
  end

  attr(:tasks, :map, required: true)
  attr(:statuses, :list, required: true)
  attr(:prefix, :string, required: true)
  attr(:repo_url, :string, default: nil)
  attr(:label_colors, :map, default: %{})

  def board(assigns) do
    ~H"""
    <div class="flex min-h-0 flex-1 p-2">
      <div class="bg-base-100 border-base-300 flex w-full flex-1 overflow-hidden rounded-xl border shadow-sm">
        <div id="board" class="flex flex-1 overflow-x-auto">
          <.column
            :for={status <- @statuses}
            status={status}
            statuses={@statuses}
            tasks={Map.get(@tasks, status, [])}
            prefix={@prefix}
            repo_url={@repo_url}
            label_colors={@label_colors}
          />
        </div>
      </div>
    </div>
    """
  end

  attr(:status, :atom, required: true)
  attr(:statuses, :list, required: true)
  attr(:tasks, :list, required: true)
  attr(:prefix, :string, required: true)
  attr(:repo_url, :string, default: nil)
  attr(:label_colors, :map, default: %{})

  def column(assigns) do
    ~H"""
    <div class="group/section min-h-0 w-64 shrink-0 overflow-y-auto rounded-lg sm:w-72">
      <div class="bg-base-100/40 h-15 sticky top-0 z-10 flex items-center px-3 backdrop-blur-sm sm:px-6">
        <div class="mr-3 flex shrink-0 justify-center">
          <.task_status_icon status={@status} />
        </div>
        <span class="text-base-content/40 font-mono mr-3 text-xs">
          [{length(@tasks)}]
        </span>
        <span class="text-base-content/80 font-mono pt-px text-xs font-semibold uppercase tracking-wide">
          {status_name(@status)}
        </span>
        <div class="flex-1" />
        <button
          class="btn btn-ghost btn-xs opacity-0 transition-opacity group-hover/section:opacity-100"
          phx-click={JS.push("open_add_modal", value: %{status: @status})}
        >
          <.icon name="hero-plus-micro" class="size-3.5" />
        </button>
      </div>
      <div
        id={"board_column_#{@status}"}
        phx-hook="Sortable"
        data-on-end="move_task"
        data-group="todo_columns"
        data-group-id={@status}
        data-animation="150"
        data-delay="300"
        data-delay-on-touch-only
        data-ghost-class="invisible"
        data-force-fallback
        class="min-h-[4rem] flex flex-col gap-3 px-3 pt-px pb-6"
      >
        <div :for={task <- @tasks} data-item-id={task.id}>
          <.task_card
            task={task}
            statuses={@statuses}
            prefix={@prefix}
            repo_url={@repo_url}
            label_colors={@label_colors}
          />
        </div>
      </div>
    </div>
    """
  end

  attr(:task, :map, required: true)
  attr(:statuses, :list, required: true)
  attr(:prefix, :string, required: true)
  attr(:repo_url, :string, default: nil)
  attr(:label_colors, :map, default: %{})

  def task_card(assigns) do
    ~H"""
    <div
      id={"card_#{@task.id}"}
      class="bg-base-100 ring-base-300 group/card block select-none rounded-lg px-3 pb-3 ring-1 transition-colors hover:ring-primary/50"
    >
      <div class="mb-1">
        <span class="text-base-content/40 font-mono text-[0.6rem]">{@prefix}-{@task.id}</span>
      </div>
      <div
        phx-click={JS.push("open_task", value: %{id: @task.id})}
        class="flex cursor-pointer items-center gap-2"
      >
        <.task_status_icon status={@task.status} />
        <div class="min-w-0 flex-1">
          <span class="text-base-content/80 line-clamp-1 text-xs font-semibold leading-tight hover:text-primary">
            {@task.title}
          </span>
        </div>
      </div>
      <p :if={@task.description != ""} class="text-base-content/40 line-clamp-3 mt-1 pl-7 text-xs">
        {@task.description}
      </p>
      <div :if={@task.labels != []} class="mt-2 flex flex-wrap gap-1 pl-7">
        <.label_badge :for={label <- @task.labels} label={label} label_colors={@label_colors} />
      </div>
      <div
        :if={@task.assignees != [] or @task.pr}
        class="text-base-content/50 mt-2 flex items-center gap-2 text-xs"
      >
        <.github_link
          :for={assignee <- @task.assignees}
          href={@repo_url && "#{@repo_url}/issues?q=assignee:#{assignee}"}
        >
          <.icon name="hero-user-micro" class="size-3" />@{assignee}
        </.github_link>
        <.github_link :if={@task.pr} href={@repo_url && "#{@repo_url}/pull/#{@task.pr}"}>
          <.icon name="hero-code-bracket-micro" class="size-3" />
          <span class="font-mono">#{@task.pr}</span>
        </.github_link>
      </div>
      <.right_click_menu id={"card_menu_#{@task.id}"} container_id={"card_#{@task.id}"}>
        <.task_context_menu task={@task} statuses={@statuses} menu_id={"card_menu_#{@task.id}"} />
      </.right_click_menu>
    </div>
    """
  end

  attr(:tasks, :map, required: true)
  attr(:statuses, :list, required: true)
  attr(:prefix, :string, required: true)
  attr(:repo_url, :string, default: nil)
  attr(:label_colors, :map, default: %{})

  def list_view(assigns) do
    ~H"""
    <div class="flex min-h-0 flex-1 p-2">
      <div class="bg-base-100 border-base-300 flex w-full flex-1 overflow-hidden rounded-xl border shadow-sm">
        <div class="flex-1 overflow-auto">
          <div class="space-y-3 py-3">
            <div :for={status <- @statuses} class="group/section">
              <div class="mb-3 flex h-9 items-center px-3 sm:px-6">
                <div class="mr-3 flex shrink-0 justify-center">
                  <.task_status_icon status={status} />
                </div>
                <span class="text-base-content/40 font-mono mr-3 text-xs">
                  [{length(Map.get(@tasks, status, []))}]
                </span>
                <span class="text-base-content/80 font-mono pt-px text-xs font-semibold uppercase tracking-wide">
                  {status_name(status)}
                </span>
                <div class="flex-1" />
                <button
                  class="btn btn-ghost btn-xs opacity-0 transition-opacity group-hover/section:opacity-100"
                  phx-click={JS.push("open_add_modal", value: %{status: status})}
                >
                  <.icon name="hero-plus-micro" class="size-3.5" />
                </button>
              </div>
              <div
                id={"list_column_#{status}"}
                phx-hook="Sortable"
                data-on-end="move_task"
                data-group="todo_columns"
                data-group-id={status}
                data-animation="150"
                data-ghost-class="invisible"
                data-force-fallback
              >
                <div
                  :for={task <- Map.get(@tasks, status, [])}
                  id={"list_row_#{task.id}"}
                  data-item-id={task.id}
                  class="group/row flex h-9 items-center rounded px-3 transition-colors hover:bg-base-200 sm:px-6"
                >
                  <div class="mr-3 flex shrink-0 justify-center">
                    <.task_status_icon status={status} />
                  </div>
                  <span
                    phx-click={JS.push("open_task", value: %{id: task.id})}
                    class="font-mono text-base-content/40 hidden w-14 shrink-0 cursor-pointer truncate text-xs hover:text-primary sm:inline"
                  >
                    {@prefix}-{task.id}
                  </span>
                  <span
                    phx-click={JS.push("open_task", value: %{id: task.id})}
                    class="text-base-content/80 min-w-0 flex-1 cursor-pointer truncate pr-3 text-xs font-semibold hover:text-primary sm:w-64 sm:flex-none"
                  >
                    {task.title}
                  </span>
                  <span class="text-base-content/40 hidden min-w-0 flex-1 truncate pr-3 text-xs md:inline">
                    {if task.description != "", do: first_line(task.description)}
                  </span>
                  <div :if={task.labels != []} class="mr-3 hidden shrink-0 items-center gap-1 sm:flex">
                    <.label_badge
                      :for={label <- task.labels}
                      label={label}
                      label_colors={@label_colors}
                    />
                  </div>
                  <div class="text-base-content/50 mr-3 hidden w-48 shrink-0 items-center justify-end gap-3 text-xs sm:flex">
                    <.github_link
                      :if={task.pr}
                      href={@repo_url && "#{@repo_url}/pull/#{task.pr}"}
                    >
                      <.icon name="hero-code-bracket-micro" class="size-3" />
                      <span class="font-mono">
                        #{task.pr}
                      </span>
                    </.github_link>
                    <.github_link
                      :for={assignee <- task.assignees}
                      href={@repo_url && "#{@repo_url}/issues?q=assignee:#{assignee}"}
                    >
                      <.icon name="hero-user-micro" class="size-3" />@{assignee}
                    </.github_link>
                  </div>
                  <div class="flex shrink-0 justify-center">
                    <div class="dropdown dropdown-end">
                      <button
                        tabindex="0"
                        role="button"
                        class="btn btn-ghost btn-xs opacity-0 transition-opacity group-hover/row:opacity-100"
                      >
                        <.icon name="hero-ellipsis-horizontal-micro" class="size-3.5" />
                      </button>
                      <div tabindex="0" class="dropdown-content z-50">
                        <.task_context_menu
                          task={task}
                          statuses={@statuses}
                          menu_id={"list_dropdown_#{task.id}"}
                        />
                      </div>
                    </div>
                  </div>
                  <.right_click_menu id={"list_menu_#{task.id}"} container_id={"list_row_#{task.id}"}>
                    <.task_context_menu
                      task={task}
                      statuses={@statuses}
                      menu_id={"list_menu_#{task.id}"}
                    />
                  </.right_click_menu>
                </div>
                <div
                  :if={Map.get(@tasks, status, []) == []}
                  class="text-base-content/30 py-2 pl-11 text-xs"
                >
                  ---
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr(:status, :atom, required: true)

  def task_status_icon(assigns) do
    status_assigns =
      case assigns.status do
        # Default statuses
        :backlog ->
          [class: "text-neutral/60 border-base-300", icon: "hero-ellipsis-horizontal"]

        :todo ->
          [class: "text-info border-info/30", icon: "hero-arrow-right"]

        :in_progress ->
          [class: "text-warning border-warning/30", icon: "hero-arrow-path"]

        :done ->
          [class: "text-success border-success/30", icon: "hero-check"]

        # Review & feedback
        :review ->
          [class: "text-purple-500 border-purple-500/30", icon: "hero-eye"]

        :feedback ->
          [class: "text-violet-500 border-violet-500/30", icon: "hero-chat-bubble-left-ellipsis"]

        :approved ->
          [class: "text-emerald-500 border-emerald-500/30", icon: "hero-hand-thumb-up"]

        # Planning & ideation
        :ideas ->
          [class: "text-amber-400 border-amber-400/30", icon: "hero-light-bulb"]

        :planning ->
          [class: "text-sky-500 border-sky-500/30", icon: "hero-map"]

        :design ->
          [class: "text-pink-500 border-pink-500/30", icon: "hero-paint-brush"]

        # Testing & QA
        :testing ->
          [class: "text-cyan-500 border-cyan-500/30", icon: "hero-beaker"]

        :qa ->
          [class: "text-teal-500 border-teal-500/30", icon: "hero-clipboard-document-check"]

        # Issue states
        :blocked ->
          [class: "text-error border-error/30", icon: "hero-no-symbol"]

        :bug ->
          [class: "text-red-500 border-red-500/30", icon: "hero-bug-ant"]

        :urgent ->
          [class: "text-rose-500 border-rose-500/30", icon: "hero-fire"]

        # Workflow
        :ready ->
          [class: "text-lime-500 border-lime-500/30", icon: "hero-rocket-launch"]

        :on_hold ->
          [class: "text-orange-400 border-orange-400/30", icon: "hero-pause"]

        :cancelled ->
          [class: "text-base-content/30 border-base-300", icon: "hero-x-mark"]

        :archived ->
          [class: "text-base-content/30 border-base-300", icon: "hero-archive-box"]

        # Catch-all
        _ ->
          [class: "text-base-content/40 border-base-300", icon: "hero-minus"]
      end

    assigns = assign(assigns, status_assigns)

    ~H"""
    <div class={[@class, "size-5 flex items-center justify-center rounded-full border"]}>
      <.icon name={@icon} class="size-3" />
    </div>
    """
  end

  attr(:href, :string, default: nil)
  attr(:class, :string, default: nil)
  slot(:inner_block, required: true)

  def github_link(assigns) do
    ~H"""
    <a
      :if={@href}
      href={@href}
      target="_blank"
      rel="noopener"
      class={[@class, "inline-flex items-center gap-1 transition-colors hover:text-primary"]}
    >
      {render_slot(@inner_block)}
    </a>
    <span :if={!@href} class={[@class, "inline-flex items-center gap-1"]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr(:warnings, :list, required: true)

  def parse_warnings(assigns) do
    ~H"""
    <div class="bg-warning/10 border-warning/30 mx-2 mt-3 rounded-lg border p-3 sm:mx-6">
      <div class="flex items-start gap-2">
        <.icon name="hero-exclamation-triangle-mini" class="size-5 text-warning mt-0.5 shrink-0" />
        <div class="min-w-0 flex-1">
          <p class="text-warning text-sm font-medium">
            {length(@warnings)} line(s) in TODO.md couldn't be parsed
          </p>
          <ul class="mt-1 space-y-0.5">
            <li
              :for={{status, line} <- @warnings}
              class="text-base-content/60 font-mono truncate text-xs"
            >
              <span class="text-base-content/40">{status_name(status)}:</span> {String.trim(line)}
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  attr(:flash, :map, required: true)
  attr(:kind, :atom, values: [:info, :error])
  attr(:rest, :global)

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      class={["fixed top-4 right-4 z-50 max-w-sm rounded-lg p-4 shadow-lg", @kind == :info && "bg-info/10 text-info border-info/30 border", @kind == :error && "bg-error/10 text-error border-error/30 border"]}
      {@rest}
    >
      <p class="text-sm">{msg}</p>
    </div>
    """
  end

  attr(:name, :string, required: true)
  attr(:class, :string, default: nil)

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  attr(:type, :string, default: "button")
  attr(:class, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def button(assigns) do
    ~H"""
    <button type={@type} class={[@class, "btn btn-primary"]} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card border-base-300 bg-base-300 relative flex flex-row items-center rounded-full border-2">
      <div class="border-1 border-base-200 bg-base-100 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left] absolute left-0 h-full w-1/3 rounded-full brightness-200" />

      <button
        class="flex w-1/3 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex w-1/3 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex w-1/3 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  attr(:id, :string, required: true)
  attr(:container_id, :string, default: nil)
  slot(:inner_block, required: true)

  def right_click_menu(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="RightClickMenu"
      data-container-id={@container_id}
      phx-remove={
        JS.hide(transition: {"transition-opacity duration-100", "opacity-100", "opacity-0"})
      }
      class="z-[9999] fixed"
      style="display: none;"
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr(:task, :map, required: true)
  attr(:statuses, :list, required: true)
  attr(:menu_id, :string, required: true)

  def task_context_menu(assigns) do
    ~H"""
    <ul class="menu bg-base-100 ring-base-300 text-base-content/60 z-50 w-52 rounded-lg p-1 text-xs shadow-lg ring-1">
      <li>
        <button
          phx-click={
            JS.exec("phx-remove", to: "##{@menu_id}") |> JS.push("open_task", value: %{id: @task.id})
          }
          class="whitespace-nowrap"
        >
          <div class="size-5 flex items-center justify-center">
            <.icon name="hero-pencil-micro" class="size-3.5" />
          </div>
          Edit
        </button>
      </li>
      <li :for={target <- @statuses} :if={target != @task.status}>
        <button
          phx-click={JS.push("move_task", value: %{item_id: @task.id, group_id: target})}
          class="whitespace-nowrap"
        >
          <.task_status_icon status={target} /> Move to {status_name(target)}
        </button>
      </li>
      <li>
        <button
          phx-click="delete_task"
          phx-value-id={@task.id}
          data-confirm="Delete this task?"
          class="text-error whitespace-nowrap"
        >
          <div class="size-5 flex items-center justify-center">
            <.icon name="hero-trash-micro" class="size-3.5" />
          </div>
          Delete
        </button>
      </li>
    </ul>
    """
  end

  attr(:label, :string, required: true)
  attr(:label_colors, :map, default: %{})

  def label_badge(assigns) do
    assigns = assign(assigns, :style, label_style(assigns.label_colors[assigns.label]))

    ~H"""
    <span
      style={@style}
      class="text-[0.6rem] inline-flex items-center rounded-full px-1.5 py-0.5 font-medium leading-none"
    >
      {@label}
    </span>
    """
  end

  attr(:all_labels, :list, required: true)
  attr(:filter_labels, :any, required: true)
  attr(:label_colors, :map, default: %{})

  def label_filter(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-1.5 px-4 pt-3 sm:px-6">
      <span class="text-base-content/40 mr-1 text-xs">
        <.icon name="hero-tag-micro" class="size-3" /> Labels
      </span>
      <button
        :for={label <- @all_labels}
        phx-click={JS.push("toggle_label", value: %{label: label})}
        style={label_style(@label_colors[label])}
        class={[
          "text-[0.65rem] inline-flex cursor-pointer items-center rounded-full px-2 py-0.5 font-medium leading-none transition-all",
          if(MapSet.member?(@filter_labels, label),
            do: "ring-2 ring-current/50",
            else: "opacity-60 hover:opacity-100"
          )
        ]}
      >
        {label}
      </button>
      <button
        :if={MapSet.size(@filter_labels) > 0}
        phx-click="clear_label_filter"
        class="text-base-content/40 ml-1 cursor-pointer text-xs hover:text-base-content/60"
      >
        clear
      </button>
    </div>
    """
  end

  @default_label_style "background-color: oklch(from currentColor l c h / 0.15); color: oklch(0.55 0.1 0)"

  defp label_style(nil), do: @default_label_style

  defp label_style(hex) do
    "background-color: #{hex}26; color: #{hex}"
  end

  def status_name(status), do: Parser.status_to_heading(status)

  defp first_line(text) do
    text |> String.split("\n", parts: 2) |> hd()
  end
end
