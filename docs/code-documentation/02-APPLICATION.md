# application.ex - OTP Application Module

## Purpose
This module is the entry point for the application's supervision tree. It starts all core processes and services when the application boots.

## Complete Code with Line-by-Line Explanation

```elixir
defmodule YoutubeVideoChatApp.Application do
```
**Line 1**: Defines the application module following OTP conventions.

---

```elixir
  @moduledoc false
```
**Line 2**: Module doc set to `false` - no public documentation needed (internal infrastructure).

---

```elixir
  use Application
```
**Line 4**: Uses the Application behavior, which requires implementing `start/2` callback.

---

```elixir
  @impl true
  def start(_type, _args) do
```
**Lines 6-7**: 
- `@impl true` - Indicates this implements a behavior callback
- `start/2` - Called when application starts
- `_type` - Application start type (usually `:normal`, unused here)
- `_args` - Start arguments (unused here)

---

```elixir
    children = [
```
**Line 8**: Defines list of child processes to supervise. Order matters!

---

```elixir
      YoutubeVideoChatAppWeb.Telemetry,
```
**Line 9**: **Telemetry Reporter** - Collects metrics and monitoring data about the application. Started first to capture all events.

---

```elixir
      YoutubeVideoChatApp.Repo,
```
**Line 10**: **Database Repository** - PostgreSQL connection pool via Ecto. Must start before anything that queries the database.

---

```elixir
      {DNSCluster, query: Application.get_env(:youtube_video_chat_app, :dns_cluster_query) || :ignore},
```
**Line 11**: **DNS Cluster Discovery** 
- Tuple format: `{module, options}`
- For distributed deployments (multiple servers)
- Gets DNS query config or uses `:ignore` if not configured
- Allows nodes to find each other automatically

---

```elixir
      {Phoenix.PubSub, name: YoutubeVideoChatApp.PubSub},
```
**Line 12**: **PubSub (Publish/Subscribe) System**
- Enables message broadcasting between processes
- Named `YoutubeVideoChatApp.PubSub` for reference throughout app
- Critical for real-time features (chat, video sync, queue updates)

---

```elixir
      YoutubeVideoChatAppWeb.Presence,
```
**Line 16**: **Presence Tracker**
- Tracks which users are in which rooms
- Uses PubSub for distributed tracking
- Automatically handles user joins/leaves

---

```elixir
      {DynamicSupervisor, name: YoutubeVideoChatApp.RoomSupervisor, strategy: :one_for_one},
```
**Line 18**: **Room Supervisor**
- `DynamicSupervisor` - Can start/stop children dynamically
- Named `YoutubeVideoChatApp.RoomSupervisor` for global access
- `strategy: :one_for_one` - If a room crashes, only restart that room
- Manages all RoomServer processes (one per active room)

**Why DynamicSupervisor?**
- Rooms are created/destroyed as users join/leave
- Number of rooms unknown at startup
- Can't use regular Supervisor which needs fixed children list

---

```elixir
      YoutubeVideoChatAppWeb.Endpoint
    ]
```
**Lines 20-21**: **HTTP Endpoint**
- Phoenix web server (handles HTTP/WebSocket)
- Started last - by this point all services are ready
- Listens for incoming connections

---

```elixir
    opts = [strategy: :one_for_one, name: YoutubeVideoChatApp.Supervisor]
```
**Line 25**: **Supervisor Options**
- `strategy: :one_for_one` - If child crashes, restart only that child (not siblings)
- `name:` - Register supervisor globally for inspection

**Other strategies:**
- `:one_for_all` - If one crashes, restart all children
- `:rest_for_one` - If one crashes, restart it and all after it

---

```elixir
    Supervisor.start_link(children, opts)
  end
```
**Lines 26-27**: 
- Start the supervisor with child list and options
- Returns `{:ok, pid}` on success
- Supervisor monitors all children, restarting them if they crash

---

```elixir
  @impl true
  def config_change(changed, _new, removed) do
```
**Lines 31-32**: **Hot Configuration Reload**
- Called when app configuration changes at runtime
- `changed` - Modified config keys
- `_new` - New config (unused)
- `removed` - Removed config keys

---

```elixir
    YoutubeVideoChatAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
```
**Lines 33-35**:
- Notifies Endpoint of config changes (restarts servers if needed)
- Returns `:ok`
- Ends module

---

## Supervision Tree Visualization

```
Application.start/2
    │
    ├─ Starts Supervisor
    │      │
    │      ├─ Child 1: Telemetry (monitors app)
    │      ├─ Child 2: Repo (database)
    │      ├─ Child 3: DNSCluster (node discovery)
    │      ├─ Child 4: PubSub (messaging)
    │      ├─ Child 5: Presence (user tracking)
    │      ├─ Child 6: RoomSupervisor (dynamic)
    │      │              │
    │      │              ├─ RoomServer (room_id_1)
    │      │              ├─ RoomServer (room_id_2)
    │      │              └─ RoomServer (room_id_N)
    │      │
    │      └─ Child 7: Endpoint (web server)
    │
    └─ Returns {:ok, pid}
```

## Process Lifecycle

**Startup:**
1. Application.start/2 called by Erlang VM
2. Supervisor starts with children list
3. Each child starts in order (top to bottom)
4. If any child fails startup, entire app fails

**Runtime:**
1. Supervisor monitors all children
2. If child crashes, supervisor receives EXIT signal
3. Supervisor restarts child based on strategy
4. Other children continue running (`:one_for_one`)

**Shutdown:**
1. Application stop signal received
2. Supervisor tells children to stop (bottom to top)
3. Each child has 5 seconds to cleanup
4. Supervisor terminates after all children stopped

## Key Concepts

### Why This Order?

1. **Telemetry first** - Captures startup events
2. **Repo second** - Database needed by many processes
3. **PubSub before Presence** - Presence uses PubSub
4. **RoomSupervisor before Endpoint** - Rooms must exist before web requests
5. **Endpoint last** - Everything ready for incoming requests

### Fault Tolerance

If a RoomServer crashes:
- Only that room affected
- Other rooms continue working
- Crashed room restarts with fresh state
- Users in crashed room reconnect automatically (LiveView)

If PubSub crashes:
- `:one_for_one` strategy means other children unaffected
- PubSub restarts immediately
- Message routing restored
- Brief interruption in real-time features

### Configuration Changes

When config changes (e.g., database credentials):
- `config_change/3` called
- Endpoint notified to restart relevant services
- No full app restart needed (hot reload)
- Zero-downtime configuration updates
