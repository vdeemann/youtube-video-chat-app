import Config

# Configure your database
config :youtube_video_chat_app, YoutubeVideoChatApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "youtube_video_chat_app_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :youtube_video_chat_app, YoutubeVideoChatAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_bytes_long_1234567890123456789012",
  server: false

# In test we don't send emails.
config :youtube_video_chat_app, YoutubeVideoChatApp.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
