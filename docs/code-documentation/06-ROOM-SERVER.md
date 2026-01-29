# 06-ROOM-SERVER.md - Room State GenServer

## File: `lib/youtube_video_chat_app/rooms/room_server.ex`

This is the **brain** of each room - a GenServer that manages playback state, queue, and synchronization for all users in a room.

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     RoomServer                               │
│                                                             │
│  State:                                                     │
│  ┌────────────────────────────────────────────────────────┐│
│  │ room_id: "uuid"                                        ││
│  │ current_media: %{title: "...", media_id: "...", ...}   ││
│  │ video_state: "playing" | "paused"                      ││
│  │ video_started_at: ~U[2024-01-28 12:00:00Z]            ││
│  │ queue: [%{...}, %{...}, ...]                          ││
│  │ host_id: "user-uuid"                                   ││
│  └────────────────────────────────────────────────────────┘│
│                                                             │
│  Client API:                                               │
│  ┌────────────────────┐  ┌────────────────────┐           │
│  │ get_state/1        │  │ add_to_queue/3     │           │
│  │ sync_video/4       │  │ play_next/1        │           │
│  │ remove_from_queue/2│  │ update_progress/3  │           │
│  └────────────────────┘  └────────────────────┘           │
│                                                             │
│  Broadcasts (via PubSub):                                  │
│  • {:media_changed, media}                                 │
│  • {:queue_updated, queue}                                 │
│  • {:play_next, media, queue}                             │
└─────────────────────────────────────────────────────────────┘
```

## Module Structure

```elixir
defmodule YoutubeVideoChatApp.Rooms.RoomServer do
  @moduledoc """
  GenServer for managing room state and video synchronization
  """
  use GenServer
  alias Phoenix.PubSub
  require Logger
```

**`use GenServer`**: Imports GenServer behavior - `start_link/1`, `init/1`, `handle_call/3`, etc.

## State Structure

```elixir
  defstruct [
    :room_id,
    :current_media,    # Currently playing media
    :video_state,      # playing/paused
    :video_timestamp,  # current playback position
    :video_started_at, # When the current video started playing
    :queue,            # upcoming media queue (not including current)
    :host_id,
    :viewers,
    :last_sync,
    :check_timer       # Timer reference for checking video progress
  ]
```

| Field | Type | Purpose |
|-------|------|---------|
| `room_id` | UUID | Unique room identifier |
| `current_media` | map \| nil | Currently playing track |
| `video_state` | string | "playing" or "paused" |
| `video_timestamp` | integer | Current position in seconds |
| `video_started_at` | DateTime | When playback started (for sync) |
| `queue` | list | Upcoming tracks |
| `host_id` | UUID | User who controls playback |
| `viewers` | MapSet | Connected user IDs |
| `last_sync` | integer | Monotonic time of last sync |
| `check_timer` | ref \| nil | Timer for backup checks |

## Client API

### start_link/1

```elixir
  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, 
      name: {:global, {:room, room_id}})
  end
```

**Purpose**: Start a new RoomServer process

**Registration**: `{:global, {:room, room_id}}`
- Globally registered name
- Accessible from any node in a cluster
- Format: `{:room, "550e8400-e29b-..."}`

### get_state/1

```elixir
  def get_state(room_id) do
    GenServer.call({:global, {:room, room_id}}, :get_state)
  catch
    :exit, _ -> {:error, :room_not_found}
  end
```

**Purpose**: Fetch current room state

**Error handling**: `catch :exit` handles case where process doesn't exist

**Usage**:
```elixir
case RoomServer.get_state(room.id) do
  {:ok, state} -> use_state(state)
  {:error, :room_not_found} -> handle_missing()
end
```

### add_to_queue/3

```elixir
  def add_to_queue(room_id, media_data, user) do
    GenServer.call({:global, {:room, room_id}}, 
      {:add_to_queue, media_data, user})
  catch
    :exit, _ -> {:error, :room_not_found}
  end
```

**Purpose**: Add a video/track to the queue

**Parameters**:
- `room_id` - Target room
- `media_data` - Map with type, media_id, title, etc.
- `user` - Who added it

### play_next/1

```elixir
  def play_next(room_id) do
    GenServer.call({:global, {:room, room_id}}, :play_next)
  catch
    :exit, _ -> {:error, :room_not_found}
  end
```

**Purpose**: Advance to next track in queue

**Called when**: Video ends OR host clicks "Skip"

### remove_from_queue/2

```elixir
  def remove_from_queue(room_id, media_id) do
    GenServer.cast({:global, {:room, room_id}}, {:remove_from_queue, media_id})
  catch
    :exit, _ -> {:error, :room_not_found}
  end
```

**Note**: Uses `cast` (async) instead of `call` (sync) - doesn't wait for response

## Server Callbacks

### init/1

```elixir
  @impl true
  def init(room_id) do
    Logger.info("RoomServer starting for room #{room_id}")
    
    # Load room from database
    room = YoutubeVideoChatApp.Rooms.get_room!(room_id)
    
    state = %__MODULE__{
      room_id: room_id,
      current_media: nil,
      video_state: "paused",
      video_timestamp: 0,
      video_started_at: nil,
      queue: [],
      host_id: room.host_id,
      viewers: MapSet.new(),
      last_sync: System.monotonic_time(:second),
      check_timer: nil
    }
    
    {:ok, state}
  end
```

**Called when**: Process starts (via `start_link/1`)

**Returns**: `{:ok, initial_state}`

### handle_call :get_state

```elixir
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end
```

**Returns**: `{:reply, response, new_state}`
- Sends `{:ok, state}` back to caller
- State unchanged

### handle_call :add_to_queue

```elixir
  @impl true
  def handle_call({:add_to_queue, media_data, user}, _from, state) do
    # Convert all keys to atoms for consistency
    media = %{
      id: Ecto.UUID.generate(),
      type: media_data["type"] || media_data[:type],
      media_id: media_data["media_id"] || media_data[:media_id],
      title: media_data["title"] || media_data[:title] || "Unknown",
      thumbnail: media_data["thumbnail"] || media_data[:thumbnail],
      duration: media_data["duration"] || media_data[:duration] || 180,
      embed_url: media_data["embed_url"] || media_data[:embed_url],
      original_url: media_data["original_url"] || media_data[:original_url],
      added_by_username: user.username,
      added_by_id: user.id,
      added_at: DateTime.utc_now()
    }
```

**Key insight**: Handles both string and atom keys for flexibility

**Logic**:
```elixir
    # If nothing playing, start immediately
    new_state = if is_nil(state.current_media) do
      Logger.info("✅ No current media, starting playback immediately")
      
      broadcast_media_change(state.room_id, media)
      broadcast_queue_update(state.room_id, state.queue)
      broadcast_play_next(state.room_id, media, state.queue)
      
      %{state | 
        current_media: media, 
        video_state: "playing",
        video_timestamp: 0,
        video_started_at: DateTime.utc_now()
      }
    else
      # Add to queue
      new_queue = state.queue ++ [media]
      broadcast_queue_update(state.room_id, new_queue)
      %{state | queue: new_queue}
    end
    
    {:reply, {:ok, media}, new_state}
  end
```

### handle_call :play_next

```elixir
  @impl true
  def handle_call(:play_next, _from, state) do
    Logger.info("=== PLAY_NEXT CALLED ===")
    
    case state.queue do
      [next | rest] ->
        # Advance to next track
        Logger.info("✅ ADVANCING TO NEXT TRACK: #{next.title}")
        
        new_state = %{state | 
          current_media: next,
          queue: rest,
          video_state: "playing",
          video_timestamp: 0,
          video_started_at: DateTime.utc_now()
        }
        
        # Broadcast AFTER updating state
        broadcast_media_change(state.room_id, next)
        broadcast_queue_update(state.room_id, rest)
        broadcast_play_next(state.room_id, next, rest)
        
        {:reply, :ok, new_state}
      
      [] ->
        # Queue empty - stop playback
        Logger.info("⚠️ Queue is empty")
        
        new_state = %{state | 
          current_media: nil,
          video_state: "paused",
          video_timestamp: 0,
          video_started_at: nil,
          queue: []
        }
        
        broadcast_media_change(state.room_id, nil)
        broadcast_queue_update(state.room_id, [])
        broadcast_play_next(state.room_id, nil, [])
        
        {:reply, :ok, new_state}
    end
  end
```

**Pattern matching on queue**:
- `[next | rest]` - Queue has items: take first, keep rest
- `[]` - Empty queue: stop playback

### handle_cast :remove_from_queue

```elixir
  @impl true
  def handle_cast({:remove_from_queue, media_id}, state) do
    Logger.info("Removing media from queue: #{media_id}")
    
    new_queue = Enum.reject(state.queue, fn media -> 
      media.id == media_id
    end)
    
    broadcast_queue_update(state.room_id, new_queue)
    {:noreply, %{state | queue: new_queue}}
  end
```

**`Enum.reject/2`**: Removes items where function returns `true`

### handle_cast :sync_video

```elixir
  @impl true
  def handle_cast({:sync_video, timestamp, video_state, user_id}, state) do
    # Only allow host to sync
    if user_id == state.host_id do
      now = System.monotonic_time(:second)
      
      PubSub.broadcast(
        YoutubeVideoChatApp.PubSub, 
        "room:#{state.room_id}", 
        {:video_sync, timestamp, video_state}
      )
      
      {:noreply, %{state | 
        video_timestamp: timestamp, 
        video_state: video_state,
        last_sync: now
      }}
    else
      {:noreply, state}
    end
  end
```

**Host-only**: Only room host can sync video position

## Private Functions

### Broadcast Helpers

```elixir
  defp broadcast_media_change(room_id, media) do
    Logger.info("📡 BROADCASTING media change")
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:media_changed, media}
    )
  end

  defp broadcast_queue_update(room_id, queue) do
    Logger.info("📡 BROADCASTING queue update")
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:queue_updated, queue}
    )
  end

  defp broadcast_play_next(room_id, media, queue) do
    Logger.info("📡 BROADCASTING play_next")
    PubSub.broadcast!(
      YoutubeVideoChatApp.PubSub,
      "room:#{room_id}",
      {:play_next, media, queue}
    )
  end
```

**`PubSub.broadcast!`**: Sends message to ALL subscribers of topic

**Topic format**: `"room:#{room_id}"` e.g. `"room:550e8400-e29b-..."`

### Timer Management

```elixir
  defp cancel_check_timer(nil), do: :ok
  defp cancel_check_timer(timer_ref) do
    Process.cancel_timer(timer_ref)
    :ok
  end
```

**Pattern matching**: `nil` case handled separately

## Message Flow Example

### Adding a Video

```
User clicks "Add" in UI
    ↓
LiveView: handle_event("add_video", ...)
    ↓
RoomServer.add_to_queue(room_id, media, user)
    ↓
GenServer.call → handle_call({:add_to_queue, ...})
    ↓
If nothing playing:
    State updated, broadcasts sent
Else:
    Added to queue, queue broadcast sent
    ↓
PubSub broadcasts to "room:#{room_id}"
    ↓
All subscribed LiveViews receive handle_info
    ↓
LiveViews update their assigns
    ↓
Templates re-render
    ↓
Browsers see update
```

### Video Ending

```
YouTube player fires "ended" event (state = 0)
    ↓
JavaScript: if host, pushVideoEnded()
    ↓
LiveView: handle_event("video_ended", ...)
    ↓
RoomServer.play_next(room_id)
    ↓
GenServer.call → handle_call(:play_next, ...)
    ↓
Take next from queue (or nil if empty)
    ↓
Update state, broadcast play_next
    ↓
All LiveViews receive {:play_next, media, queue}
    ↓
push_event("create_player", ...) sent to browsers
    ↓
JavaScript creates new player for next track
```

## Why GenServer?

### Benefits

1. **Isolated State**: Each room has its own process with its own state
2. **Concurrency**: Multiple rooms run in parallel
3. **Fault Tolerance**: One room crashing doesn't affect others
4. **Message Queue**: Requests processed sequentially (no race conditions)

### Compared to Alternatives

| Approach | Pros | Cons |
|----------|------|------|
| **GenServer** | Concurrent, isolated, sequential | Complexity |
| **ETS table** | Fast reads | Manual concurrency control |
| **Database** | Persistent | Slow for real-time |
| **Process dictionary** | Simple | Single point of failure |

## Debugging

```elixir
# In IEx, get state of a room
iex> RoomServer.get_state("room-uuid")
{:ok, %RoomServer{current_media: %{...}, queue: [...]}}

# Check if server exists
iex> GenServer.whereis({:global, {:room, "room-uuid"}})
#PID<0.456.0>  # or nil if not running

# Manual state inspection
iex> :sys.get_state({:global, {:room, "room-uuid"}})
%RoomServer{...}
```

## Related Files

| File | Relationship |
|------|--------------|
| `rooms.ex` | Creates/finds RoomServers |
| `room_live/show.ex` | Calls RoomServer functions |
| `application.ex` | Starts DynamicSupervisor |
| `app.js` | Triggers video_ended events |
