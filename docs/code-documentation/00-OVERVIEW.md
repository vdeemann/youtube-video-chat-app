# 00 — Architecture Overview

## What This Application Does

YouTube Video Chat App is a **real-time watch party platform** built with Elixir, Phoenix LiveView, and JavaScript. Users create rooms, share YouTube or SoundCloud URLs, and watch/listen together with synchronized playback and live chat.

## Tech Stack

| Layer | Technology | Role |
|-------|-----------|------|
| Language | Elixir 1.14+ | Functional, concurrent backend |
| Framework | Phoenix 1.7 + LiveView 0.20 | Web framework with real-time UI |
| Database | PostgreSQL | Persistent storage (rooms, users, playlists) |
| Real-time | Phoenix PubSub + WebSockets | State broadcasting & presence |
| Process Model | GenServer + DynamicSupervisor | Per-room stateful processes |
| Frontend JS | YouTube iFrame API, SoundCloud Widget API | Media playback |
| CSS | TailwindCSS | Utility-first styling |
| Bundler | esbuild + Tailwind CLI | Asset compilation |
| Deployment | Docker / Render.com | Containerized production |

## High-Level Architecture

```
Browser (Client)
  LiveView DOM  ◄─ JS Hooks (app.js) ── YouTube/SC iFrames
       │ WebSocket        │ pushEvent / handleEvent
       ▼                  ▼
Phoenix Server
  Endpoint (Cowboy HTTP) → Router → LiveViews
  RoomLive (LiveView) ◄─ PubSub (broadcast) ◄─ Presence
       │ call/cast         ▲ broadcast
       ▼                   │
  RoomServer (GenServer) — one per active room
  - current_track, queue[], started_at, auto-advance timer
       │
  DynamicSupervisor │ Registry │ Repo (Ecto/Postgres)
```

## Core Execution Flows

### Flow 1: User Creates a Room
1. User visits `/rooms` → `RoomLive.Index.mount/3` loads public rooms
2. User clicks "Create Room" → `handle_event("create_room")` validates auth
3. `Rooms.create_room_for_user/2` checks the 1-room-per-user limit, inserts into DB
4. User is `push_navigate`'d to `/room/:slug`

### Flow 2: User Joins a Room
1. Browser navigates to `/room/:slug` → `RoomLive.Show.mount/3`
2. Room is fetched from DB; a `RoomServer` GenServer is started if needed
3. Phoenix Presence tracks the user in topic `"room:<id>"`
4. The LiveView subscribes to PubSub topic `"room:<id>"`
5. Current playback state is fetched from `RoomServer.get_state/1`
6. A `sync_player` event is pushed to the JS hook with `{media, started_at, server_now, is_host}`

### Flow 3: Adding a Track to the Queue
1. User pastes a URL → `handle_event("add_video")` parses it (YouTube or SoundCloud)
2. `RoomServer.add_to_queue/3` is called — a `GenServer.call`
3. RoomServer builds a media map, appends to queue, calls `maybe_start_playing/1`
4. `broadcast/1` sends `{:room_state_changed, state}` to all subscribers
5. Every LiveView's `handle_info({:room_state_changed, ...})` updates assigns and pushes `sync_player` to JS

### Flow 4: Track Ends → Auto-Advance
1. YouTube `onStateChange(0)` or SoundCloud `FINISH` fires in the browser
2. JS calls `pushVideoEnded()` → LiveView `handle_event("video_ended")`
3. LiveView calls `RoomServer.track_ended/1`
4. RoomServer cancels any existing timer, pops the next track off the queue, sets `started_at = now`, schedules a new timer, and broadcasts
5. If no timer-based advancement has happened, a server-side `Process.send_after(:auto_advance)` also fires as a safety net

### Flow 5: Synchronized Playback
1. Server stores `started_at` — the ms-epoch when position 0 of the current track began
2. Every client computes: `seek_position = (Date.now() - started_at - clockOffset) / 1000`
3. A 1.5s interval drift-corrects if actual position diverges > 3s from expected
4. The host client reports progress back to the server every 1.5s, recalibrating `started_at`

## Directory Structure

```
youtube-video-chat-app/
├── assets/js/app.js              # Client-side player logic, hooks, sync
├── config/                       # Compile-time & runtime configuration
├── lib/
│   ├── youtube_video_chat_app/   # Business logic (contexts, schemas, GenServers)
│   │   ├── application.ex        # OTP supervision tree
│   │   ├── repo.ex               # Ecto repository
│   │   ├── accounts.ex           # User context
│   │   ├── rooms.ex              # Room context
│   │   ├── rooms/room_server.ex  # GenServer: queue, playback, timers
│   │   ├── playlists.ex          # Playlist context
│   │   └── playlists/            # Playlist & PlaylistItem schemas
│   └── youtube_video_chat_app_web/
│       ├── endpoint.ex           # HTTP entry point, plug pipeline
│       ├── router.ex             # URL → controller/LiveView mapping
│       ├── user_auth.ex          # Auth plugs and LiveView on_mount hooks
│       ├── presence.ex           # Phoenix Presence for online tracking
│       └── live/                 # LiveView modules
├── priv/                         # Migrations, static assets
└── test/                         # ExUnit tests
```

## Key Design Decisions

1. **GenServer per room** — All playback state lives in memory in a `RoomServer` process, not the database. This provides sub-millisecond reads and atomic state transitions without DB contention.

2. **Server-authoritative time** — The server records *when* a track started (`started_at` as ms epoch). Clients compute their own seek position. This avoids needing to synchronize a "current position" which would drift.

3. **Single broadcast event** — Every state mutation emits one PubSub message (`{:room_state_changed, map}`). The LiveView has a single handler, preventing race conditions from multiple event types.

4. **Guest + registered user model** — Guests can watch and listen; registered users can create rooms, add tracks, and chat. This lowers the barrier to entry while incentivizing registration.

5. **30-minute idle timeout** — RoomServer processes terminate after 30 minutes of no activity, freeing memory. They restart on demand when a user rejoins.
