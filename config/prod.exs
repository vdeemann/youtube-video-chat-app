import Config

# Serve digested assets (app-<hash>.js) so every deploy busts browser caches.
# Without this, prod served the unhashed /assets/app.js with cacheable
# headers and browsers kept running stale player JS across deploys.
config :youtube_video_chat_app, YoutubeVideoChatAppWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger, level: :info

# Disable Swoosh API client in production (we're not sending emails)
# This avoids the hackney dependency requirement
config :swoosh, :api_client, false

# Runtime production config is in config/runtime.exs
