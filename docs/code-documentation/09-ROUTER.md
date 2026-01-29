# 09-ROUTER.md - URL Routing and Pipelines

## File: `lib/youtube_video_chat_app_web/router.ex`

The router maps URLs to controllers and LiveViews. It defines pipelines (groups of plugs) and scopes (groups of routes).

## Complete Source Code

```elixir
defmodule YoutubeVideoChatAppWeb.Router do
  use YoutubeVideoChatAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {YoutubeVideoChatAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", YoutubeVideoChatAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/test_soundcloud", TestController, :soundcloud_test
    
    live "/room/:slug", RoomLive.Show, :show
    live "/rooms", RoomLive.Index, :index
    live "/rooms/new", RoomLive.New, :new
  end

  if Application.compile_env(:youtube_video_chat_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: YoutubeVideoChatAppWeb.Telemetry
    end
  end
end
```

## Line-by-Line Explanation

### Module Definition

```elixir
defmodule YoutubeVideoChatAppWeb.Router do
  use YoutubeVideoChatAppWeb, :router
```

**`use YoutubeVideoChatAppWeb, :router`**:
- Imports router macros (`get`, `post`, `live`, `pipe_through`, etc.)
- Defined in `youtube_video_chat_app_web.ex`

### Browser Pipeline

```elixir
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {YoutubeVideoChatAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end
```

A **pipeline** is a named group of plugs. Requests going through `:browser` get all these plugs.

| Plug | Purpose |
|------|---------|
| `:accepts, ["html"]` | Only accept HTML content type |
| `:fetch_session` | Load session from cookie |
| `:fetch_live_flash` | Load flash messages for LiveView |
| `:put_root_layout` | Set the root HTML template |
| `:protect_from_forgery` | CSRF token protection |
| `:put_secure_browser_headers` | Security headers (X-Frame-Options, etc.) |

### API Pipeline

```elixir
  pipeline :api do
    plug :accepts, ["json"]
  end
```

For JSON API endpoints (not used in this app, but available).

### Main Routes Scope

```elixir
  scope "/", YoutubeVideoChatAppWeb do
    pipe_through :browser
```

**`scope "/"...`**:
- All routes in this block start from "/"
- `YoutubeVideoChatAppWeb` is prepended to controller/LiveView modules

**`pipe_through :browser`**:
- All requests go through the `:browser` pipeline first

### Static Controller Routes

```elixir
    get "/", PageController, :home
    get "/test_soundcloud", TestController, :soundcloud_test
```

| HTTP | Path | Controller | Action |
|------|------|------------|--------|
| GET | `/` | `PageController` | `:home` |
| GET | `/test_soundcloud` | `TestController` | `:soundcloud_test` |

**How it works**:
```
GET / 
  → YoutubeVideoChatAppWeb.PageController.home(conn, params)
  → Returns HTML
```

### LiveView Routes

```elixir
    live "/room/:slug", RoomLive.Show, :show
    live "/rooms", RoomLive.Index, :index
    live "/rooms/new", RoomLive.New, :new
```

**LiveView routing differs from controllers**:
- No HTTP verbs - LiveView handles everything
- WebSocket connection established automatically
- Real-time updates without page reloads

| Path | LiveView Module | Live Action |
|------|-----------------|-------------|
| `/room/:slug` | `RoomLive.Show` | `:show` |
| `/rooms` | `RoomLive.Index` | `:index` |
| `/rooms/new` | `RoomLive.New` | `:new` |

**`:slug` parameter**:
- Dynamic URL segment
- Accessed as `params["slug"]` in mount

**Example**: `/room/cool-vibes-1234`
- Matches `/room/:slug`
- `params = %{"slug" => "cool-vibes-1234"}`

### Development Routes

```elixir
  if Application.compile_env(:youtube_video_chat_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: YoutubeVideoChatAppWeb.Telemetry
    end
  end
```

**Conditional compilation**:
- `Application.compile_env` reads config at compile time
- Dev routes only available in development

**LiveDashboard**:
- Real-time metrics dashboard
- Access at `/dev/dashboard`
- Shows processes, memory, database stats

## Route Helpers

Phoenix generates helper functions for routes:

```elixir
# In LiveView or templates
~p"/rooms"          # => "/rooms"
~p"/room/my-slug"   # => "/room/my-slug"

# Dynamic slug
~p"/room/#{room.slug}"  # => "/room/cool-vibes-1234"
```

## Request Flow

```
GET /room/cool-vibes-1234
    ↓
Router matches: live "/room/:slug", RoomLive.Show, :show
    ↓
pipe_through :browser (run all browser plugs)
    ↓
Initial HTTP request renders static HTML
    ↓
Browser loads HTML, JavaScript connects WebSocket
    ↓
WebSocket connects to /live
    ↓
RoomLive.Show.mount/3 called
    ↓
LiveView is now live!
```

## Adding New Routes

### Controller Route

```elixir
# In router
get "/about", PageController, :about
post "/contact", ContactController, :create

# In controller
def about(conn, _params) do
  render(conn, :about)
end
```

### LiveView Route

```elixir
# In router
live "/settings", SettingsLive, :index

# In lib/youtube_video_chat_app_web/live/settings_live.ex
defmodule YoutubeVideoChatAppWeb.SettingsLive do
  use YoutubeVideoChatAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div>Settings page</div>
    """
  end
end
```

### Nested Routes

```elixir
scope "/admin", YoutubeVideoChatAppWeb.Admin do
  pipe_through [:browser, :require_admin]
  
  live "/rooms", RoomLive.Index
  live "/users", UserLive.Index
end
```

### API Routes

```elixir
scope "/api", YoutubeVideoChatAppWeb do
  pipe_through :api
  
  get "/rooms", ApiController, :list_rooms
  post "/rooms", ApiController, :create_room
end
```

## Route Verification

Check routes in IEx:

```elixir
iex> YoutubeVideoChatAppWeb.Router.__routes__()
# Returns all defined routes

# Or use mix task
$ mix phx.routes
GET   /                        PageController :home
GET   /test_soundcloud         TestController :soundcloud_test
LIVE  /room/:slug              RoomLive.Show :show
LIVE  /rooms                   RoomLive.Index :index
LIVE  /rooms/new               RoomLive.New :new
```

## Security Notes

1. **CSRF Protection**: `:protect_from_forgery` adds CSRF tokens
2. **Secure Headers**: `:put_secure_browser_headers` adds:
   - `x-frame-options: SAMEORIGIN`
   - `x-content-type-options: nosniff`
   - `x-xss-protection: 1; mode=block`

3. **API routes**: Don't have CSRF protection (use API tokens instead)

## Related Files

| File | Relationship |
|------|--------------|
| `endpoint.ex` | Calls router as final plug |
| `page_controller.ex` | Handles `/` route |
| `room_live/show.ex` | Handles `/room/:slug` |
| `youtube_video_chat_app_web.ex` | Defines `:router` macro |
