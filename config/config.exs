import Config

if config_env() == :dev do
  config :esbuild,
    version: "0.24.2",
    default: [
      args: ~w(js/app.js --bundle --minify --target=es2020 --outdir=../dist/js),
      cd: Path.expand("../assets", __DIR__)
    ]

  config :tailwind,
    version: "4.1.12",
    default: [
      args: ~w(
        --input=css/app.css
        --output=../dist/css/app.css
        --minify
      ),
      cd: Path.expand("../assets", __DIR__)
    ]
end
