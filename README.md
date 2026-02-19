# YouTube Video Chat App

A real-time watch party platform built with Elixir, Phoenix LiveView, and JavaScript. Users create rooms, share YouTube or SoundCloud URLs, and watch/listen together with synchronized playback, live chat, and personal playlists.

## Documentation

Complete line-by-line code documentation is available in `docs/code-documentation/`:

- **[Code Documentation](./docs/code-documentation/README.md)** — Comprehensive guides for every source file
- **[Navigation Index](./docs/code-documentation/INDEX.md)** — Find exactly what you need
- **[Architecture Overview](./docs/code-documentation/00-OVERVIEW.md)** — System design, execution flows, and tech stack

## Features

- **YouTube & SoundCloud** — Paste any YouTube or SoundCloud URL to queue media
- **Synchronized playback** — Server-authoritative timing keeps all clients in sync
- **Auto-advancing queue** — Tracks advance automatically when one finishes
- **Real-time chat** — Instagram Live-style floating messages over the video
- **Emoji reactions** — Send floating emoji reactions
- **Presence tracking** — See who is watching in real time
- **Personal playlists** — Save and load playlists, grab currently-playing tracks
- **Guest access** — Anyone can watch; registered users can add media and chat
- **Host controls** — Room hosts can skip tracks and remove queue items

## Quick Start

### Docker (recommended)

```bash
docker-compose up
```

Open http://localhost:4000.

### Local Development

Requirements: Elixir 1.14+, PostgreSQL, Node.js.

```bash
mix deps.get
cd assets && npm install && cd ..
mix ecto.create && mix ecto.migrate
mix phx.server
```

Open http://localhost:4000.

## How It Works

1. A user creates a room. A `RoomServer` GenServer process is started to hold all playback state in memory.
2. Users join the room via WebSocket (Phoenix LiveView). Each user subscribes to the PubSub topic `"room:<id>"` and is tracked via Phoenix Presence.
3. When a URL is added, the server parses it, builds a media map, appends it to the in-memory queue, and broadcasts the updated state to all subscribers.
4. The server records `started_at` (the millisecond epoch when position 0 of the current track began). Clients compute their seek position as `(Date.now() - started_at - clockOffset) / 1000`.
5. When a track ends, the client notifies the server, which pops the next track off the queue, sets a new `started_at`, and broadcasts.
6. A server-side `Process.send_after` timer also fires as a safety net for auto-advancement.

## Supported URLs

| Platform | Formats |
|----------|---------|
| YouTube | `youtube.com/watch?v=...`, `youtu.be/...`, `youtube.com/embed/...`, bare 11-char IDs |
| SoundCloud | `soundcloud.com/artist/track` |

## Project Structure

```
├── assets/js/app.js                  # Client-side player, hooks, sync loop
├── config/                           # Compile-time and runtime configuration
├── lib/
│   ├── youtube_video_chat_app/       # Business logic layer
│   │   ├── application.ex            # OTP supervision tree
│   │   ├── repo.ex                   # Ecto repository
│   │   ├── accounts.ex               # User context (registration, auth, guests)
│   │   ├── accounts/                 # User and UserToken schemas
│   │   ├── rooms.ex                  # Room context (CRUD, slug generation)
│   │   ├── rooms/room.ex             # Room schema
│   │   ├── rooms/room_server.ex      # GenServer: queue, playback, timers
│   │   ├── playlists.ex              # Playlist context
│   │   └── playlists/                # Playlist and PlaylistItem schemas
│   └── youtube_video_chat_app_web/   # Web interface layer
│       ├── endpoint.ex               # HTTP/WebSocket entry point
│       ├── router.ex                 # URL routing and pipelines
│       ├── user_auth.ex              # Authentication plugs and LiveView hooks
│       ├── presence.ex               # Phoenix Presence
│       └── live/
│           ├── room_live/show.ex     # Main room LiveView
│           ├── room_live/show.html.heex  # Room template
│           └── room_live/index.ex    # Room listing / lobby
├── priv/                             # Migrations and static assets
├── docs/                             # All project documentation
│   └── code-documentation/           # Line-by-line code explanations
└── test/                             # ExUnit tests
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Elixir 1.14+ |
| Framework | Phoenix 1.7, LiveView 0.20 |
| Database | PostgreSQL via Ecto |
| Real-time | Phoenix PubSub, Presence, WebSockets |
| Process model | GenServer + DynamicSupervisor + Registry |
| Frontend | YouTube iFrame API, SoundCloud Widget API, TailwindCSS |
| Bundler | esbuild + Tailwind CLI |
| Deployment | Docker, Render.com |

## Development

```bash
mix test                                    # Run tests
mix assets.build                            # Rebuild CSS/JS
docker-compose exec web mix assets.build    # Rebuild in Docker
```

## Troubleshooting

**Queue not advancing?** Hard-refresh (`Ctrl+Shift+R`), make sure you are the host, and check the browser console (F12) for errors.

**bcrypt error on Windows?** Use Docker, which handles native compilation automatically. The app falls back to `pbkdf2_elixir` on Windows.

**Port 4000 in use?** Run `docker-compose down` or kill the local process.

## License

MIT
