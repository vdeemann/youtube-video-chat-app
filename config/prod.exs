import Config

# Do not print debug messages in production
config :logger, level: :info

# Disable Swoosh API client in production (we're not sending emails)
# This avoids the hackney dependency requirement
config :swoosh, :api_client, false

# Runtime production config is in config/runtime.exs
