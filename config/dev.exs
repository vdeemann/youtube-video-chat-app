import Config

# Configure your database
# Use DATABASE_URL if available (for Docker), otherwise use localhost
if database_url = System.get_env("DATABASE_URL") do
  config :youtube_video_chat_app, YoutubeVideoChatApp.Repo,
    url: database_url,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10
else
  config :youtube_video_chat_app, YoutubeVideoChatApp.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "youtube_video_chat_app_dev",
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10
end

# For development, we disable any cache and enable
# debugging and code reloading.
config :youtube_video_chat_app, YoutubeVideoChatAppWeb.Endpoint,
  # Binding to all interfaces to allow access from Docker host
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "ysF8H3vkCxQPQ5GHJrvLxNyVkQTNE2Lx8vY3N7gJ6UQKjmXGpvRrQTx1234567890",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:youtube_video_chat_app, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:youtube_video_chat_app, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :youtube_video_chat_app, YoutubeVideoChatAppWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/youtube_video_chat_app_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :youtube_video_chat_app, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
