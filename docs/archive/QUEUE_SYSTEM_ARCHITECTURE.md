# Understanding the Queue System Flow

## Architecture Overview

The queue system has three main components working together:

### 1. Server State (RoomServer GenServer)
```
current_media: The video/track playing right now
queue: Array of upcoming media (NOT including current)
```

**Example State:**
```elixir
%{
  current_media: %{title: "Video 1", type: "youtube", ...},
  queue: [
    %{title: "Video 2", type: "youtube", ...},
    %{title: "Video 3", type: "soundcloud", ...}
  ]
}
```

### 2. Client Detection (JavaScript)
- **YouTube**: Uses iframe API to detect state changes
- **SoundCloud**: Uses Widget API to detect FINISH event
- Both send `video_ended` event to server when done

### 3. LiveView Updates (Phoenix PubSub)
- Server broadcasts state changes to all connected clients
- All viewers see synchronized queue and playback

## The Flow of Operations

### Adding First Media
```
User adds Video 1
  ↓
RoomServer.add_to_queue()
  ↓
current_media = nil? YES
  ↓
Set current_media = Video 1
queue = []
  ↓
Broadcast: media_changed, play_next
  ↓
All clients start playing Video 1
UI shows: Queue is empty
```

### Adding Second Media
```
User adds Video 2
  ↓
RoomServer.add_to_queue()
  ↓
current_media = Video 1? YES
  ↓
Add to queue
queue = [Video 2]
  ↓
Broadcast: queue_updated
  ↓
All clients show Video 2 in queue
```

### Auto-Advance When Video Ends
```
Video 1 finishes playing
  ↓
JavaScript detects end
  ↓
Sends video_ended event
  ↓
Only HOST processes it
  ↓
RoomServer.play_next()
  ↓
[Video 2, Video 3] = queue
  ↓
Extract first item:
  next = Video 2
  rest = [Video 3]
  ↓
Update state:
  current_media = Video 2
  queue = [Video 3]
  ↓
Broadcast to ALL clients:
  - media_changed: Video 2
  - queue_updated: [Video 3]
  - play_next: Video 2
  ↓
All clients:
  - Start playing Video 2
  - Update queue to show only Video 3
```

## Why This Works

### 1. Separation of Concerns
- **current_media**: What's playing NOW
- **queue**: What's playing NEXT
- They never overlap

### 2. Single Source of Truth
- Server maintains the authoritative state
- Clients receive updates via PubSub
- No client-side state conflicts

### 3. Host-Only Advancement
- Only the HOST's client detects video end
- Prevents race conditions
- All other clients wait for broadcast

### 4. Reliable Detection
Multiple detection methods for YouTube:
- API state change (state === 0)
- Progress tracking (currentTime >= duration)
- Stuck detection (no progress near end)
- 98% threshold check

SoundCloud uses native FINISH event.

## State Transitions

### Empty State
```
current_media: nil
queue: []
→ Nothing playing, nothing queued
```

### Playing with Empty Queue
```
current_media: Video 1
queue: []
→ Video 1 playing, nothing after
→ When Video 1 ends, returns to empty state
```

### Playing with Queue
```
current_media: Video 1
queue: [Video 2, Video 3]
→ Video 1 playing, 2 more queued
→ When Video 1 ends, Video 2 becomes current
→ New state: current = Video 2, queue = [Video 3]
```

## Broadcast Events

### media_changed
Sent when the current playing media changes
```elixir
{:media_changed, media}
```

### queue_updated
Sent when the upcoming queue changes
```elixir
{:queue_updated, [list of media]}
```

### play_next
Combined event with both current and queue
```elixir
{:play_next, current_media, queue}
```

## Client Handling

### LiveView Handlers
```elixir
handle_info({:media_changed, media}, socket) ->
  Update current_media assign
  Reload iframe with new media

handle_info({:queue_updated, queue}, socket) ->
  Update queue assign
  UI re-renders queue list

handle_info({:play_next, media, queue}, socket) ->
  Update both assigns
  Force iframe reload
```

### JavaScript Hook
```javascript
handleEvent("reload_iframe", ({media}) => {
  // Clean up old player
  // Update iframe src
  // Re-initialize player
})
```

## Edge Cases Handled

### 1. Multiple Rapid Additions
Queue grows sequentially, order preserved

### 2. Video Ends While Adding
State update serialized, no conflicts

### 3. All Viewers Leave
Server keeps state, new joiners see current state

### 4. Host Leaves During Playback
Other viewers can't advance, but can add to queue
New host would need to be designated

### 5. Network Interruption
Client reconnects, gets current state from server

## Debugging Checklist

When something goes wrong, check:

1. ✅ Is current_media set correctly?
2. ✅ Is queue array in correct order?
3. ✅ Did broadcasts fire?
4. ✅ Did all clients receive broadcasts?
5. ✅ Is JavaScript detecting video end?
6. ✅ Is play_next being called?
7. ✅ Is state updating before broadcasting?

## Performance Considerations

### Memory
- Each room has one GenServer
- Queue size unlimited (consider adding limit)
- Media objects are small (~500 bytes each)

### Network
- Broadcasts to N clients per event
- 3 broadcasts per advancement
- Low bandwidth (JSON objects)

### CPU
- YouTube: Polling every 500ms for progress
- SoundCloud: Event-driven (more efficient)
- Minimal server CPU usage

## Future Enhancements

Possible improvements:
1. Drag-and-drop queue reordering
2. Queue size limits
3. Queue persistence (database)
4. Playlist templates
5. Vote-to-skip system
6. Auto-queue recommendations
7. Shuffle mode
8. Repeat mode
