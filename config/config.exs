# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

config :youtube_video_chat_app,
  ecto_repos: [YoutubeVideoChatApp.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :youtube_video_chat_app, YoutubeVideoChatAppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: YoutubeVideoChatAppWeb.ErrorHTML, json: YoutubeVideoChatAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: YoutubeVideoChatApp.PubSub,
  live_view: [signing_salt: "4kGfN8xJ"]

# Configures the mailer
config :youtube_video_chat_app, YoutubeVideoChatApp.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  youtube_video_chat_app: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  youtube_video_chat_app: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
