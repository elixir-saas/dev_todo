defmodule DevTodoTest do
  use ExUnit.Case

  test "version in README matches mix.exs" do
    mix_version = DevTodo.MixProject.project()[:version]
    readme_content = File.read!("README.md")

    version_regex = ~r/\{:dev_todo, "~> ([^"]+)"/

    assert [_, readme_version] = Regex.run(version_regex, readme_content),
           "Could not find version in README.md installation section"

    assert readme_version == mix_version,
           "Version mismatch: mix.exs has '#{mix_version}' but README has '#{readme_version}'"
  end
end
