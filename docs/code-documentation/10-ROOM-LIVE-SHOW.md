# 10-ROOM-LIVE-SHOW.md - Main Room LiveView Module

## File: `lib/youtube_video_chat_app_web/live/room_live/show.ex`

This is the **heart of the application** - the LiveView that manages the room experience including video playback, chat, and user presence.

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    RoomLive.Show                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐  │
│  │  Mount/Init     │  │  Event Handlers │  │  PubSub     │  │
│  │  - Load room    │  │  - send_message │  │  Messages   │  │
│  │  - Create user  │  │  - add_video    │  │  - chat     │  │
│  │  - Subscribe    │  │  - video_ended  │  │  - queue    │  │
│  │  - Track presence│ │  - reactions    │  │  - media    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Module Structure

```elixir
defmodule YoutubeVideoChatAppWeb.RoomLive.Show do
  use YoutubeVideoChatAppWeb, :live_view
  
  # Aliases for cleaner code
  alias YoutubeVideoChatApp.{Rooms, Accounts}
  alias YoutubeVideoChatApp.Rooms.RoomServer
  alias YoutubeVideoChatAppWeb.Presence
  alias Phoenix.PubSub
  require Logger
  
  # ... implementation
end
```

## Mount Function - Initialization

```elixir
@impl true
def mount(%{"slug" => slug}, _session, socket) do
```

**Called when**: User navigates to `/room/:slug`

### Step 1: Load Room from Database

```elixir
  room = Rooms.get_room_by_slug!(slug)
```
- Finds room by URL slug (e.g., "cool-vibes-1234")
- Raises `Ecto.NoResultsError` if not found (404)

### Step 2: Create Guest User

```elixir
  user = Accounts.create_guest_user()
```
- Creates anonymous user with random name and color
- Example: `%{id: "uuid", username: "Guest4523", color: "#FF6B6B"}`

### Step 3: Ensure RoomServer Running

```elixir
  Rooms.ensure_room_server(room.id)
```
- Starts a RoomServer GenServer if not already running
- RoomServer manages queue, playback state, timing

### Step 4: Check Presence Before Joining

```elixir
  presence_before_join = if connected?(socket) do
    existing = Presence.list("room:#{room.id}")
    map_size(existing)
  else
    0
  end
```
- **Why**: First user in room becomes host
- `connected?(socket)` - true after WebSocket connects
- Initial HTTP render → `connected? = false`
- After WS connects → mount called again with `connected? = true`

### Step 5: Subscribe to PubSub

```elixir
  if connected?(socket) do
    PubSub.subscribe(YoutubeVideoChatApp.PubSub, "room:#{room.id}")
```
- Subscribes to room's broadcast channel
- Will receive: `:new_message`, `:queue_updated`, `:play_next`, etc.

### Step 6: Track Presence

```elixir
    {:ok, _} = Presence.track(self(), "room:#{room.id}", user.id, %{
      username: user.username,
      color: user.color,
      joined_at: System.system_time(:second)
    })
```
- Adds user to presence tracker
- Other clients see them join
- Metadata stored: username, color, join time

### Step 7: Get Room State

```elixir
  room_state = case RoomServer.get_state(room.id) do
    {:ok, state} -> state
    {:error, :room_not_found} -> %{current_media: nil, queue: [], ...}
  end
```
- Fetches current playback state from RoomServer
- Includes: current media, queue, playback position

### Step 8: Calculate Playback Position

```elixir
  current_timestamp = calculate_current_timestamp(room_state)
```
- Syncs new users to current position
- Based on when video started and elapsed time

### Step 9: Determine Host Status

```elixir
  is_host = user.id == room.host_id or presence_before_join == 0
```
- Host if: You created the room OR you're first in room
- Host can: skip tracks, remove from queue

### Step 10: Set Up Socket Assigns

```elixir
  socket = socket
  |> assign(:room, room)
  |> assign(:user, user)
  |> assign(:messages, [])
  |> assign(:current_media, room_state.current_media)
  |> assign(:queue, room_state.queue)
  |> assign(:is_host, is_host)
  # ... more assigns
  |> push_event("set_host_status", %{is_host: is_host})
```

**Assigns** are the LiveView's state - they become `@variable` in templates.

### Step 11: Create Player for Existing Media

```elixir
  socket = if room_state.current_media do
    push_event(socket, "create_player", %{
      media: media_for_js,
      started_at: ...,
      is_host: is_host
    })
  else
    socket
  end
```
- If room has active media, tell JavaScript to create player
- `push_event` sends data to client-side hooks

## Event Handlers

### Send Chat Message

```elixir
@impl true
def handle_event("send_message", %{"message" => msg}, socket) do
  message = %{
    id: Ecto.UUID.generate(),
    text: msg,
    username: socket.assigns.user.username,
    color: socket.assigns.user.color,
    timestamp: DateTime.utc_now()
  }
  
  PubSub.broadcast(
    YoutubeVideoChatApp.PubSub, 
    "room:#{socket.assigns.room.id}", 
    {:new_message, message}
  )
  
  {:noreply, socket}
end
```

**Flow**:
1. User submits chat form
2. Create message struct with user info
3. Broadcast to all room subscribers
4. All clients (including sender) receive via `handle_info`

### Add Video to Queue

```elixir
@impl true
def handle_event("add_video", %{"url" => url}, socket) do
  media_data = parse_media_url(cleaned_url)
  
  if media_data do
    {:ok, _media} = RoomServer.add_to_queue(
      socket.assigns.room.id,
      media_data,
      socket.assigns.user
    )
    {:noreply, assign(socket, :add_video_url, "")}
  else
    {:noreply, put_flash(socket, :error, "Invalid URL")}
  end
end
```

**Flow**:
1. Parse URL (YouTube or SoundCloud)
2. Extract media info (title, thumbnail, ID)
3. Add to RoomServer queue
4. RoomServer broadcasts update to all clients

### Video Ended (Auto-advance)

```elixir
@impl true
def handle_event("video_ended", _params, socket) do
  if socket.assigns.is_host do
    RoomServer.play_next(socket.assigns.room.id)
  end
  {:noreply, socket}
end
```

**Why host-only?**
- Prevents race conditions
- Only one person triggers advancement
- JavaScript sends this when video ends

### Send Reaction

```elixir
@impl true
def handle_event("send_reaction", %{"emoji" => emoji}, socket) do
  PubSub.broadcast(
    YoutubeVideoChatApp.PubSub,
    "room:#{socket.assigns.room.id}",
    {:reaction, %{
      id: Ecto.UUID.generate(),
      emoji: emoji,
      username: socket.assigns.user.username
    }}
  )
  {:noreply, socket}
end
```

## PubSub Message Handlers

### New Chat Message

```elixir
@impl true
def handle_info({:new_message, message}, socket) do
  messages = [message | socket.assigns.messages] |> Enum.take(100)
  {:noreply, assign(socket, :messages, messages)}
end
```
- Prepends new message to list
- Keeps last 100 messages
- Template auto-updates

### Queue Updated

```elixir
@impl true
def handle_info({:queue_updated, queue}, socket) do
  {:noreply, assign(socket, :queue, queue)}
end
```
- Updates queue display
- Triggered when: video added, removed, or played

### Play Next Track

```elixir
@impl true
def handle_info({:play_next, media, queue}, socket) do
  # Check if track actually changed
  old_track_id = socket.assigns[:last_played_track_id]
  new_track_id = media && media.id
  
  if old_track_id != new_track_id do
    # Create new player
    socket
    |> assign(:current_media, media)
    |> assign(:queue, queue)
    |> push_event("create_player", %{media: media_for_js, ...})
  else
    # Just update queue
    assign(socket, :queue, queue)
  end
end
```

**Key insight**: Only create new player when track changes to prevent interruption.

### Reaction Animation

```elixir
@impl true
def handle_info({:reaction, reaction}, socket) do
  {:noreply, push_event(socket, "show_reaction", reaction)}
end
```
- Pushes to JavaScript for animation

### Presence Updates

```elixir
@impl true
def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
  new_presences = socket.assigns.presences
  |> handle_leaves_map(diff.leaves)
  |> handle_joins_map(diff.joins)
  
  {:noreply, assign(socket, :presences, new_presences)}
end
```
- Updates viewer count
- Triggered when users join/leave

## URL Parsing

### YouTube URL Parser

```elixir
defp extract_youtube_id(url) do
  cond do
    # youtube.com/watch?v=ID
    String.contains?(url, "youtube.com/watch?v=") ->
      case Regex.run(~r/[?&]v=([A-Za-z0-9_-]{11})/, url) do
        [_, video_id] -> video_id
        _ -> nil
      end
    
    # youtu.be/ID
    String.contains?(url, "youtu.be/") ->
      case Regex.run(~r/youtu\.be\/([A-Za-z0-9_-]{11})/, url) do
        [_, video_id] -> video_id
        _ -> nil
      end
    
    # youtube.com/embed/ID
    String.contains?(url, "youtube.com/embed/") ->
      case Regex.run(~r/embed\/([A-Za-z0-9_-]{11})/, url) do
        [_, video_id] -> video_id
        _ -> nil
      end
  end
end
```

**Supported formats**:
- `https://www.youtube.com/watch?v=dQw4w9WgXcQ`
- `https://youtu.be/dQw4w9WgXcQ`
- `https://www.youtube.com/embed/dQw4w9WgXcQ`

### SoundCloud URL Parser

```elixir
defp extract_soundcloud_data(url) do
  # Parse URL
  uri = URI.parse(url)
  
  # Extract artist/track from path
  # e.g., /artist-name/track-name
  path_parts = uri.path |> String.split("/")
  
  # Build embed URL
  embed_url = "https://w.soundcloud.com/player/?url=#{encoded_url}&auto_play=true..."
  
  %{
    "type" => "soundcloud",
    "media_id" => generated_id,
    "title" => "Track by Artist",
    "embed_url" => embed_url
  }
end
```

## Helper Functions

### Calculate Current Timestamp

```elixir
defp calculate_current_timestamp(room_state) do
  case {room_state.current_media, room_state.video_started_at, room_state.video_state} do
    {nil, _, _} -> 0
    {_, nil, _} -> room_state.video_timestamp || 0
    {_, started_at, "playing"} ->
      now = DateTime.utc_now()
      elapsed = DateTime.diff(now, started_at, :second)
      base_timestamp + elapsed
    {_, _, "paused"} -> room_state.video_timestamp || 0
  end
end
```

**Purpose**: Sync new users to correct position in video

### Linkify Text

```elixir
defp linkify_text(text) do
  url_regex = ~r/(https?:\/\/[^\s]+)/
  
  # Split text, find URLs, convert to links/images
  parts = String.split(text, url_regex, include_captures: true)
  
  # Check if URL is an image
  if String.match?(url, ~r/\.(jpg|jpeg|png|gif|webp)/i) do
    # Return image tag
  else
    # Return link tag
  end
end
```

**Features**:
- Turns URLs into clickable links
- Embeds images directly in chat

## Socket Assigns Reference

| Assign | Type | Purpose |
|--------|------|---------|
| `room` | `%Room{}` | Room database record |
| `user` | `%{}` | Current guest user |
| `messages` | `[%{}]` | Chat history |
| `current_media` | `%{} \| nil` | Playing media |
| `queue` | `[%{}]` | Upcoming tracks |
| `is_host` | `boolean` | Host privileges |
| `presences` | `%{}` | Connected users |
| `show_chat` | `boolean` | Chat visibility |
| `show_queue` | `boolean` | Queue panel visibility |

## Related Files

| File | Purpose |
|------|---------|
| `show.html.heex` | Template for this LiveView |
| `room_server.ex` | Queue/playback state management |
| `app.js` | Client-side player logic |
| `presence.ex` | User presence tracking |
