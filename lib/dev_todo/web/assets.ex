defmodule DevTodo.Web.Assets do
  @moduledoc false
  import Plug.Conn

  @dist_css Path.expand("../../../dist/css/app.css", __DIR__)
  @dist_js Path.expand("../../../dist/js/app.js", __DIR__)

  @external_resource @dist_css
  @external_resource @dist_js

  # Load Phoenix JS deps from their OTP app dirs at compile time,
  # same approach as phoenix_live_dashboard.
  @phoenix_js (for app <- [:phoenix, :phoenix_html, :phoenix_live_view] do
                 path = Application.app_dir(app, ["priv", "static", "#{app}.js"])
                 Module.put_attribute(__MODULE__, :external_resource, path)
                 path |> File.read!() |> String.replace("//# sourceMappingURL=", "// ")
               end)
              |> Enum.join("\n")

  @compiled_css File.read!(@dist_css)
  @compiled_js @phoenix_js <> "\n" <> File.read!(@dist_js)

  @compiled_hashes %{
    css: Base.encode16(:crypto.hash(:md5, @compiled_css), case: :lower),
    js: Base.encode16(:crypto.hash(:md5, @compiled_js), case: :lower)
  }

  def init(asset) when asset in [:css, :js], do: asset

  def call(conn, asset) do
    {contents, content_type} = contents_and_type(asset)

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header(
      "cache-control",
      if(dev?(), do: "no-cache", else: "public, max-age=31536000, immutable")
    )
    |> put_private(:plug_skip_csrf_protection, true)
    |> send_resp(200, contents)
    |> halt()
  end

  defp contents_and_type(:css) do
    if dev?() do
      {read_from_disk(:css), "text/css"}
    else
      {@compiled_css, "text/css"}
    end
  end

  defp contents_and_type(:js) do
    if dev?() do
      {read_from_disk(:js), "text/javascript"}
    else
      {@compiled_js, "text/javascript"}
    end
  end

  defp read_from_disk(:css), do: File.read!(@dist_css)
  defp read_from_disk(:js), do: @phoenix_js <> "\n" <> File.read!(@dist_js)

  def current_hash(:css) do
    if dev?() do
      Base.encode16(:crypto.hash(:md5, read_from_disk(:css)), case: :lower)
    else
      @compiled_hashes.css
    end
  end

  def current_hash(:js) do
    if dev?() do
      Base.encode16(:crypto.hash(:md5, read_from_disk(:js)), case: :lower)
    else
      @compiled_hashes.js
    end
  end

  defp dev?, do: Application.get_env(:dev_todo, :dev, false)
end
