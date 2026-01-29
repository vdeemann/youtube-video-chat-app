# 08-ENDPOINT.md - HTTP/WebSocket Endpoint Configuration

## File: `lib/youtube_video_chat_app_web/endpoint.ex`

The Endpoint is the entry point for all web requests. It's a series of plugs (middleware) that process requests before they reach your router.

## Complete Source Code

```elixir
defmodule YoutubeVideoChatAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :youtube_video_chat_app

  @session_options [
    store: :cookie,
    key: "_youtube_video_chat_app_key",
    signing_salt: "NxP8vKmQ",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :youtube_video_chat_app,
    gzip: false,
    only: YoutubeVideoChatAppWeb.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :youtube_video_chat_app
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug YoutubeVideoChatAppWeb.Router
end
```

## Line-by-Line Explanation

### Module Definition

```elixir
defmodule YoutubeVideoChatAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :youtube_video_chat_app
```

**`use Phoenix.Endpoint`**:
- Makes this module a Phoenix Endpoint
- Provides configuration, supervision, and request handling
- Creates a supervision tree for the endpoint

**`otp_app: :youtube_video_chat_app`**:
- Tells Phoenix which application config to read
- Configuration comes from `config/*.exs` files

### Session Options

```elixir
  @session_options [
    store: :cookie,
    key: "_youtube_video_chat_app_key",
    signing_salt: "NxP8vKmQ",
    same_site: "Lax"
  ]
```

**Session configuration**:

| Option | Value | Purpose |
|--------|-------|---------|
| `store` | `:cookie` | Store session in browser cookie (encrypted) |
| `key` | `"_youtube_video_chat_app_key"` | Cookie name |
| `signing_salt` | `"NxP8vKmQ"` | Salt for signing/encryption |
| `same_site` | `"Lax"` | CSRF protection level |

**Security**: Session data is encrypted and signed - users can't read or tamper with it.

### LiveView WebSocket

```elixir
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]
```

**Purpose**: Configures the WebSocket endpoint for LiveView

**Breakdown**:
- `"/live"` - WebSocket URL path
- `Phoenix.LiveView.Socket` - Handler module
- `connect_info: [session: @session_options]` - Pass session to LiveView

**What happens**:
1. Browser connects to `ws://localhost:4000/live`
2. Phoenix upgrades HTTP to WebSocket
3. LiveView processes handle bidirectional communication

### Static File Serving

```elixir
  plug Plug.Static,
    at: "/",
    from: :youtube_video_chat_app,
    gzip: false,
    only: YoutubeVideoChatAppWeb.static_paths()
```

**Purpose**: Serve static files (CSS, JS, images)

| Option | Value | Purpose |
|--------|-------|---------|
| `at` | `"/"` | URL prefix for static files |
| `from` | `:youtube_video_chat_app` | Load from priv/static |
| `gzip` | `false` | Don't serve gzipped versions |
| `only` | `static_paths()` | Only serve specific directories |

**`static_paths()`** returns: `~w(assets fonts images favicon.ico robots.txt)`

### Development-Only Plugs

```elixir
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :youtube_video_chat_app
  end
```

**Only in development**:

| Plug | Purpose |
|------|---------|
| `LiveReloader.Socket` | WebSocket for live reload |
| `Phoenix.LiveReloader` | Triggers browser refresh |
| `Phoenix.CodeReloader` | Recompiles changed code |
| `CheckRepoStatus` | Warns about pending migrations |

### Request Logging

```elixir
  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
```

**Purpose**: Enables request logging for LiveDashboard

**How to use**:
1. Visit `/dev/dashboard`
2. Click on a request
3. See detailed request info

### Request Processing Plugs

```elixir
  plug Plug.RequestId
```
- Adds unique `x-request-id` header to each request
- Useful for tracing requests in logs

```elixir
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
```
- Emits telemetry events for monitoring
- Events: `[:phoenix, :endpoint, :start]`, `[:phoenix, :endpoint, :stop]`

```elixir
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
```
- Parses request bodies
- `:urlencoded` - Form data (`application/x-www-form-urlencoded`)
- `:multipart` - File uploads (`multipart/form-data`)
- `:json` - JSON bodies (`application/json`)

```elixir
  plug Plug.MethodOverride
```
- Allows `_method` parameter to override HTTP method
- Example: POST with `_method=DELETE` becomes DELETE

```elixir
  plug Plug.Head
```
- Converts HEAD requests to GET
- Returns only headers (no body)

### Session and Router

```elixir
  plug Plug.Session, @session_options
  plug YoutubeVideoChatAppWeb.Router
```

**`Plug.Session`**:
- Decrypts/encrypts session cookie
- Makes `conn.private.plug_session` available

**`Router`**:
- Final plug - dispatches to controllers/LiveViews
- **Must be last** - after all preprocessing

## Request Flow

```
HTTP Request
    ↓
Plug.Static (if static file, serve and stop)
    ↓
Plug.RequestId (add tracking ID)
    ↓
Plug.Telemetry (emit start event)
    ↓
Plug.Parsers (parse body)
    ↓
Plug.MethodOverride (check _method)
    ↓
Plug.Head (handle HEAD)
    ↓
Plug.Session (decrypt session)
    ↓
Router (dispatch to handler)
    ↓
Plug.Telemetry (emit stop event)
    ↓
HTTP Response
```

## Configuration

### From config/dev.exs

```elixir
config :youtube_video_chat_app, YoutubeVideoChatAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "...",
  watchers: [
    esbuild: {Esbuild, :install_and_run, ...},
    tailwind: {Tailwind, :install_and_run, ...}
  ]
```

**Key options**:

| Option | Purpose |
|--------|---------|
| `http: [port: 4000]` | Listen on port 4000 |
| `check_origin: false` | Allow any origin (dev only!) |
| `secret_key_base` | Key for encryption/signing |
| `watchers` | Asset build tools to run |

## Supervision

The endpoint is supervised:

```elixir
# In application.ex
children = [
  # ...
  YoutubeVideoChatAppWeb.Endpoint
]
```

If the endpoint crashes, the supervisor restarts it.

## Custom Plugs Example

You could add custom plugs:

```elixir
# Before the router
plug :log_request_info

defp log_request_info(conn, _opts) do
  Logger.info("Request from: #{conn.remote_ip}")
  conn
end
```

## Security Considerations

1. **Session signing_salt**: Don't commit to source control
2. **secret_key_base**: Generate unique per environment
3. **check_origin**: Enable in production (CSRF protection)
4. **same_site: "Lax"**: Prevents cross-site request attacks

## Related Files

| File | Relationship |
|------|--------------|
| `router.ex` | Receives requests from endpoint |
| `config/dev.exs` | Endpoint configuration |
| `application.ex` | Starts endpoint supervision |
| `telemetry.ex` | Handles telemetry events |
