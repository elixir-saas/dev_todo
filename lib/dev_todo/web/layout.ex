defmodule DevTodo.Web.Layout do
  @moduledoc false
  use DevTodo.Web, :html

  embed_templates("layouts/*")

  def render("root.html", assigns), do: root(assigns)

  @compile {:no_warn_undefined, Phoenix.VerifiedRoutes}

  defp asset_path(conn, asset) when asset in [:css, :js] do
    prefix = conn.private.phoenix_router.__dev_todo_prefix__()
    hash = DevTodo.Web.Assets.current_hash(asset)

    Phoenix.VerifiedRoutes.unverified_path(
      conn,
      conn.private.phoenix_router,
      "#{prefix}/#{asset}-#{hash}"
    )
  end
end
