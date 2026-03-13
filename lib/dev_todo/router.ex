defmodule DevTodo.Router do
  @moduledoc """
  Provides a `dev_todo/1` macro for mounting the DevTodo board in your router.

  ## Usage

      import DevTodo.Router

      scope "/dev" do
        pipe_through :browser
        dev_todo "/todo"
      end

  ## Options

    * `:on_mount` - A list of `Phoenix.LiveView.on_mount/1` callbacks to
      add to the live session. A single value may also be declared.

    * `:root_layout` - The root layout to use for the DevTodo live session.
      If not provided, DevTodo's own root layout is used.

    * `:as` - The name of the live session. Defaults to `:dev_todo`.
      Useful if you need to mount DevTodo multiple times with different configs.
  """

  defmacro dev_todo(path, opts \\ []) do
    scope =
      quote bind_quoted: binding() do
        scope path, alias: false, as: false do
          {session_name, session_opts, route_opts} = DevTodo.Router.__options__(opts)

          import Phoenix.Router, only: [get: 4]
          import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

          live_session session_name, session_opts do
            get("/css-:md5", DevTodo.Web.Assets, :css, as: :dev_todo_asset)
            get("/js-:md5", DevTodo.Web.Assets, :js, as: :dev_todo_asset)

            live("/", DevTodo.Web.IndexLive, :board, route_opts)
            live("/list", DevTodo.Web.IndexLive, :list, route_opts)
          end
        end
      end

    quote do
      unquote(scope)

      unless Module.get_attribute(__MODULE__, :dev_todo_prefix) do
        @dev_todo_prefix Phoenix.Router.scoped_path(__MODULE__, path)
                         |> String.replace_suffix("/", "")
        def __dev_todo_prefix__, do: @dev_todo_prefix
      end
    end
  end

  @doc false
  def __options__(opts) do
    session_name = Keyword.get(opts, :as, :dev_todo)

    root_layout = Keyword.get(opts, :root_layout, {DevTodo.Web.Layout, :root})

    session_opts = [
      root_layout: root_layout,
      on_mount: opts[:on_mount] || nil
    ]

    route_opts = []

    {session_name, session_opts, route_opts}
  end
end
