# YouTube Video Chat App - Complete Code Documentation

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Directory Structure](#directory-structure)
5. [Core Components](#core-components)

## Project Overview

The YouTube Video Chat App is a real-time collaborative video watching platform built with Elixir, Phoenix LiveView, and JavaScript. It allows multiple users to watch YouTube and SoundCloud content together in synchronized rooms with live chat functionality.

### Key Features

- **Real-time Room Management**: Create and join watching rooms
- **Multi-platform Support**: YouTube and SoundCloud integration
- **Synchronized Playback**: Automatic video advancement and queue management
- **Live Chat**: Real-time messaging with presence tracking
- **Guest System**: No authentication required - instant anonymous access
- **Queue System**: Add videos to a playlist for continuous playback
- **Host Controls**: Room creators can manage playback and queue

## Architecture

The application follows a distributed, event-driven architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Layer                          │
│  (Phoenix LiveView + JavaScript Hooks + Media Players)       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ↓ WebSocket (Phoenix Channels)
┌─────────────────────────────────────────────────────────────┐
│                   Phoenix LiveView Layer                     │
│              (RoomLive.Show - State Management)              │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ↓ PubSub Messages
┌─────────────────────────────────────────────────────────────┐
│                   Business Logic Layer                       │
│              (RoomServer GenServer - Room State)             │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ↓ Database Operations
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                              │
│                (PostgreSQL via Ecto)                         │
└─────────────────────────────────────────────────────────────┘
```

### Event Flow Example: Adding a Video

```
User enters URL
    ↓
LiveView handles "add_video" event
    ↓
Parses URL (YouTube/SoundCloud)
    ↓
Calls RoomServer.add_to_queue/3
    ↓
RoomServer updates state
    ↓
Broadcasts {:queue_updated, queue} via PubSub
    ↓
All connected LiveView clients receive update
    ↓
UI updates for all viewers
```

## Technology Stack

### Backend
- **Elixir 1.14+**: Functional programming language
- **Phoenix 1.7.11**: Web framework
- **Phoenix LiveView 0.20.2**: Real-time server-rendered UI
- **Ecto 3.11**: Database wrapper and query generator
- **PostgreSQL**: Relational database
- **Phoenix PubSub**: Distributed messaging

### Frontend
- **JavaScript ES6+**: Client-side logic
- **TailwindCSS**: Utility-first CSS framework
- **Alpine.js** (embedded in LiveView): Reactive attributes
- **YouTube IFrame API**: YouTube video control
- **SoundCloud Widget API**: SoundCloud audio control

### DevOps
- **Docker**: Containerization
- **Docker Compose**: Multi-container orchestration
- **esbuild**: JavaScript bundling
- **Mix**: Elixir build tool

## Directory Structure

```
youtube-video-chat-app/
├── assets/                      # Frontend assets
│   ├── css/                     # Stylesheets
│   │   └── app.css             # Main CSS with Tailwind
│   └── js/                      # JavaScript
│       ├── app.js              # Main JS entry point
│       └── hooks/              # Phoenix LiveView hooks
│           ├── media_player_ultimate.js  # Primary media player
│           ├── youtube_player.js         # YouTube-specific
│           └── media_player_simplified.js # Fallback version
│
├── config/                      # Application configuration
│   ├── config.exs              # Base configuration
│   ├── dev.exs                 # Development settings
│   ├── prod.exs                # Production settings (if exists)
│   ├── runtime.exs             # Runtime configuration
│   └── test.exs                # Test environment settings
│
├── lib/
│   ├── youtube_video_chat_app/           # Core business logic
│   │   ├── accounts.ex                   # User/guest management
│   │   ├── application.ex                # OTP application
│   │   ├── mailer.ex                     # Email functionality
│   │   ├── repo.ex                       # Database repository
│   │   └── rooms/                        # Room management
│   │       ├── room.ex                   # Room schema/model
│   │       └── room_server.ex            # Room state GenServer
│   │   └── rooms.ex                      # Room context/API
│   │
│   └── youtube_video_chat_app_web/      # Web interface
│       ├── components/                   # Reusable UI components
│       │   ├── core_components.ex        # Core UI elements
│       │   ├── layouts.ex                # Layout components
│       │   └── layouts/                  # Layout templates
│       │       ├── app.html.heex         # Main app layout
│       │       └── root.html.heex        # Root HTML structure
│       ├── controllers/                  # HTTP controllers
│       │   ├── page_controller.ex        # Home page
│       │   └── test_controller.ex        # Test routes
│       ├── live/                         # LiveView modules
│       │   └── room_live/
│       │       ├── index.ex              # Room list page
│       │       ├── show.ex               # Room view/logic
│       │       └── show.html.heex        # Room template
│       ├── endpoint.ex                   # HTTP endpoint config
│       ├── gettext.ex                    # Internationalization
│       ├── presence.ex                   # User presence tracking
│       ├── router.ex                     # URL routing
│       └── telemetry.ex                  # Metrics/monitoring
│   └── youtube_video_chat_app_web.ex     # Web module definitions
│
├── priv/                        # Private application files
│   ├── gettext/                # Translation files
│   ├── repo/                   # Database files
│   │   ├── migrations/         # Schema migrations
│   │   └── seeds.exs          # Seed data
│   └── static/                 # Static assets (compiled)
│
├── test/                        # Test files
│   └── test_helper.exs         # Test configuration
│
├── docs/                        # Documentation
│   ├── features/               # Feature documentation
│   ├── setup/                  # Setup guides
│   └── development/            # Development notes
│
├── scripts/                     # Utility scripts
│   ├── docker/                 # Docker-related scripts
│   ├── development/            # Dev helper scripts
│   └── maintenance/            # Maintenance scripts
│
├── mix.exs                      # Project definition
├── mix.lock                    # Dependency lock file
├── Dockerfile                  # Production Docker image
├── docker-compose.yml          # Docker services definition
└── README.md                   # Project readme
```

## Core Components

### 1. Application Supervision Tree

```
YoutubeVideoChatApp.Application (Supervisor)
├── YoutubeVideoChatAppWeb.Telemetry
├── YoutubeVideoChatApp.Repo (Database)
├── DNSCluster
├── Phoenix.PubSub (Message broker)
├── YoutubeVideoChatAppWeb.Presence (Presence tracking)
├── DynamicSupervisor (RoomSupervisor - manages RoomServers)
└── YoutubeVideoChatAppWeb.Endpoint (HTTP server)
```

### 2. Key Processes

- **RoomServer (GenServer)**: One per room, manages room state, queue, and playback
- **LiveView Processes**: One per connected client, handles UI state
- **Presence Process**: Tracks which users are in which rooms
- **PubSub**: Broadcasts events between processes

### 3. Data Flow

**State Management:**
- Room persistent data: PostgreSQL (via Ecto)
- Room runtime state: RoomServer GenServer (in-memory)
- User session state: LiveView assigns (in-memory)
- Presence data: Phoenix.Presence (distributed, in-memory)

**Communication:**
- Client ↔ Server: WebSocket (Phoenix Channels)
- Server ↔ Server: PubSub (for multi-node support)
- LiveView ↔ RoomServer: GenServer calls/casts
- Broadcast to all: PubSub.broadcast

### 4. Security Model

- Guest-based system (no authentication)
- Room access controlled by URL slugs
- Host privileges determined by `host_id`
- Input validation on all user inputs
- CSRF protection enabled
- XSS protection via Phoenix HTML escaping

---

**Next:** Continue to specific file documentation for detailed line-by-line explanations.
