defmodule DevTodo.Web do
  @moduledoc false

  def live_view do
    quote do
      use Phoenix.LiveView, layout: false

      import DevTodo.Web.Components

      alias Phoenix.LiveView.JS

      @compile {:no_warn_undefined, Phoenix.VerifiedRoutes}

      defp dev_todo_path(socket, path \\ "") do
        prefix = socket.router.__dev_todo_prefix__()

        Phoenix.VerifiedRoutes.unverified_path(
          socket,
          socket.router,
          "#{prefix}#{path}"
        )
      end
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.HTML

      alias Phoenix.LiveView.JS
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
