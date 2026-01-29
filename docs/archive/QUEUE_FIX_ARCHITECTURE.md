# Queue Auto-Advancement - Visual Flow

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      BROWSER (CLIENT)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         YouTube/SoundCloud Iframe                    │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  Video/Track Playing                          │  │  │
│  │  │  [=========>........................] 45%     │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  │         │                                             │  │
│  │         │ (1) Iframe API Events                      │  │
│  │         ▼                                             │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │    MediaPlayer Hook (media_player.js)         │  │  │
│  │  │                                                │  │  │
│  │  │  ┌──────────────────────────────────────────┐ │  │  │
│  │  │  │ YouTube Detection:                       │ │  │  │
│  │  │  │ • State Change (state === 0)            │ │  │  │
│  │  │  │ • Time Threshold (time >= duration-1)   │ │  │  │
│  │  │  │ • Progress Monitor (every 2s)           │ │  │  │
│  │  │  └──────────────────────────────────────────┘ │  │  │
│  │  │                                                │  │  │
│  │  │  ┌──────────────────────────────────────────┐ │  │  │
│  │  │  │ SoundCloud Detection:                    │ │  │  │
│  │  │  │ • FINISH Event                          │ │  │  │
│  │  │  │ • Position Monitor (every 2s)           │ │  │  │
│  │  │  └──────────────────────────────────────────┘ │  │  │
│  │  │                                                │  │  │
│  │  │         │                                      │  │  │
│  │  │         │ (2) pushEvent("video_ended")        │  │  │
│  │  │         ▼                                      │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ WebSocket
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    PHOENIX SERVER (ELIXIR)                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │    RoomLive.Show (LiveView)                         │  │
│  │                                                      │  │
│  │  handle_event("video_ended", params, socket)        │  │
│  │         │                                            │  │
│  │         │ (3) Check if user is host                 │  │
│  │         │                                            │  │
│  │         ▼                                            │  │
│  │  if is_host:                                         │  │
│  │    RoomServer.play_next(room_id) ────────┐          │  │
│  │  else:                                    │          │  │
│  │    ignore event                           │          │  │
│  └───────────────────────────────────────────┼──────────┘  │
│                                              │              │
│                                              │              │
│  ┌───────────────────────────────────────────▼──────────┐  │
│  │         RoomServer (GenServer)                      │  │
│  │                                                     │  │
│  │  handle_call(:play_next, _from, state)             │  │
│  │         │                                           │  │
│  │         │ (4) Get next item from queue              │  │
│  │         │                                           │  │
│  │         ▼                                           │  │
│  │  case state.queue:                                  │  │
│  │    [next | rest] ->                                │  │
│  │      • Update state (current_media, queue)         │  │
│  │      • Broadcast to all clients ─────┐             │  │
│  │    [] ->                              │             │  │
│  │      • Stop playback                  │             │  │
│  └───────────────────────────────────────┼─────────────┘  │
│                                          │                 │
└──────────────────────────────────────────┼─────────────────┘
                                           │
                 ┌─────────────────────────┴─────────────────┐
                 │          PubSub Broadcast                 │
                 │  "room:#{room_id}"                        │
                 │                                           │
                 │  • {:media_changed, media}                │
                 │  • {:queue_updated, queue}                │
                 │  • {:play_next, media, queue}             │
                 └───────────────┬───────────────────────────┘
                                 │
     ┌───────────────────────────┼───────────────────────────┐
     │                           │                           │
     ▼                           ▼                           ▼
┌─────────┐               ┌─────────┐                ┌─────────┐
│ Client1 │               │ Client2 │                │ Client3 │
│ (Host)  │               │(Viewer) │                │(Viewer) │
│         │               │         │                │         │
│ • Update│               │ • Update│                │ • Update│
│   UI    │               │   UI    │                │   UI    │
│ • Reload│               │ • Reload│                │ • Reload│
│   iframe│               │   iframe│                │   iframe│
└─────────┘               └─────────┘                └─────────┘
```

## Event Flow Diagram

```
TIME ────────────────────────────────────────────────────────────>

HOST BROWSER:
  │
  ├─ Video Playing [==================>........] 80%
  │                 
  ├─ Video Continues [========================>] 99%
  │                 
  ├─ Video Ends [=============================>] 100%
  │              │
  │              └─> YouTube API fires state change event
  │                  OR
  │                  Time threshold reached (currentTime >= duration-1)
  │                  
  ├─ MediaPlayer Hook detects end
  │              │
  │              └─> Sets hasEnded = true (prevent duplicates)
  │              │
  │              └─> pushEvent("video_ended", {...})
  │
  ▼

PHOENIX SERVER:
  │
  ├─ Receives video_ended event
  │              │
  │              ├─> Check: Is sender the host?
  │              │      YES: Continue
  │              │      NO:  Ignore event
  │              │
  │              └─> RoomServer.play_next(room_id)
  │                            │
  ├─ RoomServer:               │
  │    • Gets next item from queue
  │    • Updates current_media
  │    • Updates queue (remove next item)
  │    • Broadcasts to ALL clients
  │
  ▼

ALL CLIENTS (Host + Viewers):
  │
  ├─ Receive PubSub broadcasts:
  │    • {:media_changed, next_media}
  │    • {:queue_updated, new_queue}
  │    • {:play_next, next_media, new_queue}
  │
  ├─ LiveView handles broadcasts
  │              │
  │              └─> push_event("reload_iframe", {media: ...})
  │
  ├─ Client updates UI:
  │    • Current media changes
  │    • Queue updates
  │    • Iframe src changes
  │
  ├─ MediaPlayer Hook reloads:
  │    • Cleans up old listeners
  │    • Updates iframe src
  │    • Reinitializes detection
  │
  ├─ New video/track starts playing!
  │
  ▼

  (Cycle repeats)
```

## Detection Methods Comparison

### YouTube

```
METHOD 1: State Change (Primary)
┌─────────────────────────────────────┐
│ YouTube Iframe API                  │
│ onStateChange event                 │
│ playerState === 0 (ENDED)           │
│                                     │
│ Pros: Official API, reliable       │
│ Cons: Requires proper initialization│
└─────────────────────────────────────┘

METHOD 2: Time Threshold (Backup)
┌─────────────────────────────────────┐
│ getCurrentTime() >= duration - 1s   │
│                                     │
│ Pros: Works even if API fails      │
│ Cons: Less precise                  │
└─────────────────────────────────────┘

METHOD 3: Progress Monitor (Safety Net)
┌─────────────────────────────────────┐
│ Check every 2 seconds               │
│ Monitors currentTime progress       │
│                                     │
│ Pros: Catches edge cases            │
│ Cons: Polling overhead              │
└─────────────────────────────────────┘
```

### SoundCloud

```
METHOD 1: FINISH Event (Primary)
┌─────────────────────────────────────┐
│ SoundCloud Widget API               │
│ SC.Widget.Events.FINISH             │
│                                     │
│ Pros: Official event, accurate     │
│ Cons: Requires Widget API load     │
└─────────────────────────────────────┘

METHOD 2: Position Monitor (Backup)
┌─────────────────────────────────────┐
│ getPosition() every 2 seconds       │
│ position >= duration - 2s           │
│                                     │
│ Pros: Reliable fallback             │
│ Cons: Slight delay possible         │
└─────────────────────────────────────┘
```

## State Machine

```
┌─────────────┐
│   IDLE      │ No media playing
│             │
└──────┬──────┘
       │ add_to_queue() with empty queue
       ▼
┌─────────────┐
│  LOADING    │ Iframe src updated
│             │
└──────┬──────┘
       │ MediaPlayer hook mounted
       ▼
┌─────────────┐
│  PLAYING    │ Video/track playing
│             │ Detection active
│             │ Progress monitoring
└──────┬──────┘
       │ video_ended event
       ▼
┌─────────────┐
│  ADVANCING  │ play_next() called
│             │ Broadcasting changes
└──────┬──────┘
       │
       ├─> Queue not empty
       │   └──> Back to LOADING
       │
       └─> Queue empty
           └──> Back to IDLE
```

## Queue State Example

```
Initial State:
┌──────────────────────────────────────┐
│ Current: [Video A] Playing          │
│ Queue:   [Video B, Video C, Video D] │
└──────────────────────────────────────┘

After Video A ends:
┌──────────────────────────────────────┐
│ Current: [Video B] Playing          │
│ Queue:   [Video C, Video D]          │
└──────────────────────────────────────┘

After Video B ends:
┌──────────────────────────────────────┐
│ Current: [Video C] Playing          │
│ Queue:   [Video D]                   │
└──────────────────────────────────────┘

After Video C ends:
┌──────────────────────────────────────┐
│ Current: [Video D] Playing          │
│ Queue:   []                          │
└──────────────────────────────────────┘

After Video D ends:
┌──────────────────────────────────────┐
│ Current: nil                         │
│ Queue:   []                          │
│ Status:  Playback stopped            │
└──────────────────────────────────────┘
```
