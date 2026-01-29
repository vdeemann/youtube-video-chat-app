# 12-PRESENCE.md - User Presence Tracking

## File: `lib/youtube_video_chat_app_web/presence.ex`

Phoenix Presence tracks who is connected to what, with automatic cleanup when users disconnect.

## Complete Source Code

```elixir
defmodule YoutubeVideoChatAppWeb.Presence do
  @moduledoc """
  Provides presence tracking for rooms and users.
  """
  use Phoenix.Presence,
    otp_app: :youtube_video_chat_app,
    pubsub_server: YoutubeVideoChatApp.PubSub
end
```

## Line-by-Line Explanation

### Module Definition

```elixir
defmodule YoutubeVideoChatAppWeb.Presence do
```
- Web layer module (hence the `Web` in the name)
- Handles real-time user tracking

### Documentation

```elixir
  @moduledoc """
  Provides presence tracking for rooms and users.
  """
```
- Describes module purpose
- Accessible via `h YoutubeVideoChatAppWeb.Presence` in IEx

### Using Phoenix.Presence

```elixir
  use Phoenix.Presence,
    otp_app: :youtube_video_chat_app,
    pubsub_server: YoutubeVideoChatApp.PubSub
```

**`use Phoenix.Presence`**:
- Imports presence tracking functionality
- Creates a CRDT (Conflict-free Replicated Data Type) for distributed tracking
- Handles network partitions gracefully

**Options**:

| Option | Value | Purpose |
|--------|-------|---------|
| `otp_app` | `:youtube_video_chat_app` | Configuration source |
| `pubsub_server` | `YoutubeVideoChatApp.PubSub` | Broadcast mechanism |

## How Presence Works

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Phoenix Presence                          │
│                                                             │
│  ┌─────────────────┐        ┌─────────────────┐            │
│  │  User A joins   │        │  User B joins   │            │
│  │  track(pid, ...) │        │  track(pid, ...)│            │
│  └────────┬────────┘        └────────┬────────┘            │
│           │                          │                      │
│           ▼                          ▼                      │
│  ┌─────────────────────────────────────────────┐            │
│  │              PubSub "room:123"               │            │
│  │  presence_diff broadcast to all subscribers  │            │
│  └─────────────────────────────────────────────┘            │
│                                                             │
│  Tracked Data: %{"user_id" => %{metas: [%{...}]}}          │
└─────────────────────────────────────────────────────────────┘
```

### Provided Functions

Phoenix.Presence adds these functions to your module:

```elixir
# Track a user
Presence.track(self(), "room:123", user_id, %{username: "Guest", color: "#FF6B6B"})

# List all presences in a topic
Presence.list("room:123")
# => %{"user_id_1" => %{metas: [%{username: "Guest1", ...}]},
#      "user_id_2" => %{metas: [%{username: "Guest2", ...}]}}

# Get presences for specific key
Presence.get_by_key("room:123", "user_id_1")
```

## Usage in LiveView

### Tracking a User (mount)

```elixir
def mount(%{"slug" => slug}, _session, socket) do
  if connected?(socket) do
    # Subscribe to room channel
    PubSub.subscribe(YoutubeVideoChatApp.PubSub, "room:#{room.id}")
    
    # Track this user's presence
    {:ok, _} = Presence.track(self(), "room:#{room.id}", user.id, %{
      username: user.username,
      color: user.color,
      joined_at: System.system_time(:second)
    })
  end
  
  # Initialize presences from current list
  socket = handle_joins(socket, Presence.list("room:#{room.id}"))
  
  {:ok, socket}
end
```

**Key points**:
- Only track when `connected?(socket)` is true
- `self()` is the LiveView process PID
- When process dies, presence is automatically removed

### Handling Presence Updates

```elixir
@impl true
def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
  new_presences = socket.assigns.presences
  |> handle_leaves_map(diff.leaves)
  |> handle_joins_map(diff.joins)
  
  {:noreply, assign(socket, :presences, new_presences)}
end
```

**`presence_diff` payload**:
```elixir
%{
  joins: %{"new_user_id" => %{metas: [%{username: "Guest9999", ...}]}},
  leaves: %{"old_user_id" => %{metas: [%{username: "Guest1234", ...}]}}
}
```

### Helper Functions

```elixir
defp handle_joins_map(presences, joins) do
  Enum.reduce(joins, presences, fn {user_id, %{metas: [meta | _]}}, acc ->
    Map.put(acc, user_id, meta)
  end)
end

defp handle_leaves_map(presences, leaves) do
  Enum.reduce(leaves, presences, fn {user_id, _}, acc ->
    Map.delete(acc, user_id)
  end)
end
```

## Presence Data Structure

### Internal Storage

```elixir
%{
  "user_abc123" => %{
    metas: [
      %{
        username: "Guest4523",
        color: "#FF6B6B",
        joined_at: 1706500000,
        phx_ref: "F3Jz8mQ..."  # Internal reference
      }
    ]
  },
  "user_def456" => %{
    metas: [
      %{
        username: "Guest8901",
        color: "#4ECDC4",
        joined_at: 1706500100,
        phx_ref: "F3Kz9nR..."
      }
    ]
  }
}
```

**Why `metas` is a list?**
- A user can be present multiple times (e.g., multiple browser tabs)
- Each presence is a separate entry in `metas`

### Simplified for UI

In LiveView, we often simplify to:

```elixir
%{
  "user_abc123" => %{username: "Guest4523", color: "#FF6B6B"},
  "user_def456" => %{username: "Guest8901", color: "#4ECDC4"}
}
```

## Display in Template

```heex
<%= map_size(@presences) %> watching
```

Or showing usernames:

```heex
<div class="viewers">
  <%= for {_user_id, meta} <- @presences do %>
    <span style={"color: #{meta.color}"}><%= meta.username %></span>
  <% end %>
</div>
```

## Why Phoenix Presence?

### Problem Without Presence

Without presence tracking, you'd need to:
1. Store "user online" in database
2. Poll for updates
3. Handle cleanup when user disconnects (what if they don't send "leaving"?)
4. Handle server crashes, network issues, etc.

### Phoenix Presence Solution

- **Automatic cleanup**: When LiveView process dies, presence is removed
- **Distributed**: Works across multiple servers
- **CRDT-based**: Eventually consistent, handles network partitions
- **Real-time**: Instant updates via PubSub

## Lifecycle

```
User navigates to /room/xyz
    ↓
LiveView.mount/3 called (connected? = false, HTTP render)
    ↓
Browser receives HTML, connects WebSocket
    ↓
LiveView.mount/3 called again (connected? = true)
    ↓
Presence.track(self(), topic, user_id, metadata)
    ↓
PubSub broadcasts presence_diff to all subscribers
    ↓
All LiveViews receive handle_info({:presence_diff, ...})
    ↓
UI updates to show new user
    ...
User closes browser/navigates away
    ↓
LiveView process terminates
    ↓
Presence automatically cleaned up
    ↓
PubSub broadcasts presence_diff (leave)
    ↓
All LiveViews receive and update UI
```

## Configuration

In `application.ex`:

```elixir
children = [
  # PubSub must start before Presence
  {Phoenix.PubSub, name: YoutubeVideoChatApp.PubSub},
  # Presence uses PubSub
  YoutubeVideoChatAppWeb.Presence,
  # ...
]
```

## Debugging

```elixir
# In IEx
iex> YoutubeVideoChatAppWeb.Presence.list("room:abc123")
%{
  "user_123" => %{metas: [%{username: "Guest1234", ...}]}
}

# Count presences
iex> Presence.list("room:abc123") |> map_size()
3
```

## Related Files

| File | Relationship |
|------|--------------|
| `application.ex` | Starts Presence in supervision tree |
| `live/room_live/show.ex` | Tracks and handles presence |
| `show.html.heex` | Displays viewer count |
