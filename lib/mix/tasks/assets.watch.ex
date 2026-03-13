if Code.ensure_loaded?(Esbuild) do
  defmodule Mix.Tasks.Assets.Watch do
    @shortdoc "Watch and rebuild assets on change"
    @moduledoc false

    use Mix.Task

    @impl true
    def run(_args) do
      spawn_link(fn -> Esbuild.install_and_run(:default, ~w(--watch)) end)
      spawn_link(fn -> Tailwind.install_and_run(:default, ~w(--watch)) end)
      Process.sleep(:infinity)
    end
  end
end
