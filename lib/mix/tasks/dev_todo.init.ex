defmodule Mix.Tasks.DevTodo.Init do
  @moduledoc """
  Creates a starter `TODO.md` and adds DevTodo configuration to your project.

      $ mix dev_todo.init

  This task will:

    * Create a `TODO.md` file in your project root (if one doesn't exist)
    * Append DevTodo configuration to `config/dev.exs` (if not already configured)
    * Print instructions for adding the route and supervision tree entries
  """

  @shortdoc "Sets up DevTodo in your project"

  use Mix.Task

  @todo_md """
  <!--
  TODO.md — Project Task Board

  - Prefix: DEV

  Rules for AI agents editing this file:
  - Sections are defined by ## headings (e.g., ## In Progress, ## Todo)
  - To add a new status, add a new ## heading — the board adapts automatically
  - Task format: `- [N] Task title @assignee #pr:123` where N is a number
  - IDs are auto-incrementing integers (the board displays them as PREFIX-N, e.g., DEV-1)
  - Do not reuse IDs — always use the next available number
  - To move a task, cut the line and paste under the target section header
  - Order within a section = priority (top = highest)
  - Descriptions: indent lines under a task with 2+ spaces
  - Attachments: reference with `^path/to/file`
  - Do not reorder or remove existing section headers
  -->

  ## In Progress

  ## Todo

  - [2] Star dev_todo on GitHub
    https://github.com/elixir-saas/dev_todo

  ## Backlog

  ## Done

  - [1] Install dev_todo to manage my tasks
  """

  @impl Mix.Task
  def run(_args) do
    app = Mix.Project.config()[:app]
    pubsub = app_module(app, "PubSub")
    web_module = app_module(app, "Web")

    create_todo_md()
    configure_dev_exs(pubsub)
    print_instructions(app, pubsub, web_module)
  end

  defp create_todo_md do
    path = "TODO.md"

    if File.exists?(path) do
      Mix.shell().info("* #{path} already exists, skipping")
    else
      File.write!(path, @todo_md)
      Mix.shell().info("* created #{path}")
    end
  end

  defp configure_dev_exs(pubsub) do
    path = "config/dev.exs"

    if File.exists?(path) do
      content = File.read!(path)

      if content =~ "config :dev_todo" do
        Mix.shell().info("* #{path} already configured, skipping")
      else
        config_line = "\nconfig :dev_todo, pubsub: #{pubsub}\n"
        File.write!(path, content <> config_line)
        Mix.shell().info("* added DevTodo config to #{path}")
      end
    else
      Mix.shell().info("* #{path} not found, skipping config")
    end
  end

  defp print_instructions(app, pubsub, _web_module) do
    Mix.shell().info("""

    DevTodo is almost ready! Complete the setup:

    1. Add to your supervision tree in lib/#{app}/application.ex:

        children = [
          #{pubsub},
          # ... other children ...
          DevTodo.Supervisor,
          #{app |> Atom.to_string() |> Macro.camelize()}Web.Endpoint
        ]

    2. Add to your router in lib/#{Atom.to_string(app) |> String.replace("_", "_")}_web/router.ex:

        import DevTodo.Router

        # Inside your existing dev_routes block:
        scope "/dev" do
          pipe_through :browser
          dev_todo "/todo"
        end

    3. Start your server and visit /dev/todo

    For the full setup guide, see the README.
    """)
  end

  defp app_module(app, suffix) do
    app
    |> Atom.to_string()
    |> Macro.camelize()
    |> then(&"#{&1}.#{suffix}")
  end
end
