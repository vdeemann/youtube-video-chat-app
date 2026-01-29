# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Docker Development (Recommended)

#### Quick Start
```bash
# Start the application with Docker
docker-compose up

# Start in background
docker-compose up -d

# Stop the application
docker-compose down
```

#### Docker Commands
```bash
# Rebuild containers (after dependency changes)
docker-compose up --build

# View logs
docker-compose logs -f
docker-compose logs -f web    # Just web container logs

# Restart specific service
docker-compose restart web

# Access Elixir console
docker-compose exec web iex -S mix

# Run mix commands in container
docker-compose exec web mix test
docker-compose exec web mix ecto.migrate
docker-compose exec web mix ecto.reset

# Access PostgreSQL
docker-compose exec db psql -U postgres

# Clean everything (nuclear option)
docker-compose down -v --remove-orphans
```

### Local Development (Alternative)

#### Setup and Installation
```bash
# Full setup (recommended for new environments)
mix setup

# Individual steps
mix deps.get               # Install Elixir dependencies
mix ecto.setup            # Create and migrate database
cd assets && npm install  # Install Node.js dependencies
mix assets.build          # Build CSS and JS assets
```

#### Running the Application
```bash
# Start Phoenix server (default: localhost:4000)
mix phx.server

# Start with live reloading for development
mix phx.server
```

### Testing
```bash
# Docker
docker-compose exec web mix test
docker-compose exec web mix test --cover

# Local
mix test
mix test test/path/to/test_file.exs
mix test --cover
```

### Database Operations
```bash
# Docker
docker-compose exec web mix ecto.reset
docker-compose exec web mix ecto.migrate
docker-compose exec web mix ecto.gen.migration migration_name

# Local
mix ecto.reset
mix ecto.migrate
mix ecto.gen.migration migration_name
```

### Asset Management
```bash
# Docker
docker-compose exec web mix assets.build
docker-compose exec web mix assets.deploy

# Local
mix assets.build
mix assets.deploy
```

## Docker Configuration

### Development Setup
- **Dockerfile.dev**: Optimized for hot reloading and development
- **docker-compose.yml**: Orchestrates web app and PostgreSQL database
- **Elixir 1.17.3**: Compatible with Phoenix 1.7.x (avoids Elixir 1.18 issues)
- **PostgreSQL 15**: Database with health checks and persistent storage

### Container Services
- **web**: Phoenix application (port 4000)
- **db**: PostgreSQL database (port 5432)

### Volume Mounts
- Source code mounted for live reloading
- Database data persisted across restarts
- Build artifacts excluded from sync (_build, deps, node_modules)

### Environment Variables
- `DATABASE_URL`: Points to containerized PostgreSQL
- `MIX_ENV=dev`: Development environment
- `PHX_HOST=localhost`: Host configuration

## Architecture Overview

This is a real-time YouTube watch party application built with **Phoenix LiveView**. The architecture centers around synchronized video playback and real-time communication.

### Key Components

#### Backend Architecture
- **RoomServer (GenServer)**: Core state management for each room
  - Manages video queue, current playback state, and synchronization
  - Handles automatic video advancement with duration-based timers
  - Location: `lib/youtube_video_chat_app/rooms/room_server.ex`
  
- **RoomLive.Show (LiveView)**: Main real-time UI controller
  - Handles user interactions (chat, video queueing, controls)
  - Manages presence tracking and UI state
  - Location: `lib/youtube_video_chat_app_web/live/room_live/show.ex`

- **Phoenix PubSub**: Real-time message broadcasting
  - Video synchronization events
  - Chat messages and reactions
  - Queue updates and media changes

- **Phoenix Presence**: User presence tracking
  - Shows who's currently watching
  - Handles join/leave events

#### Media Support
- **YouTube Integration**: Iframe-based player with JavaScript API
- **SoundCloud Support**: Embedded player with custom parsing
- **Queue System**: DJ-style playlist management with voting capabilities

#### Database Schema
- **Rooms**: Persistent room storage with host management
- **Users**: Guest user system with generated usernames and colors
- **Messages**: Chat history (optional persistence)

### State Management Flow

1. **Room Creation**: User creates room → RoomServer GenServer spawns
2. **Media Addition**: User adds URL → Parser extracts metadata → Added to queue or starts playing
3. **Synchronization**: Host controls playback → RoomServer broadcasts state → All clients update
4. **Auto-Advancement**: Timer tracks duration → Automatically plays next in queue
5. **Real-time Updates**: All state changes broadcast via PubSub to connected clients

### Key Patterns

#### Error Handling
- All RoomServer calls wrapped in `try/catch` for `:exit` cases
- Graceful degradation when servers aren't available
- Client-side error boundaries for media loading

#### Real-time Synchronization
- Host-driven playback control (only host can sync video state)
- Automatic queue advancement with duration timers
- Fallback mechanisms for missed events

#### Media Parsing
- YouTube: Multiple URL formats supported (youtube.com, youtu.be, embed)
- SoundCloud: Robust URL parsing with fallback title generation
- Extensible parser system for additional media sources

## Development Notes

### Environment Compatibility
- **Docker (Recommended)**: Isolates Elixir 1.17.3 in container, avoiding version conflicts
- **Local Development**: Requires Elixir 1.17.x (Elixir 1.18+ has Phoenix 1.7 compatibility issues)
- **Database**: PostgreSQL required (automated in Docker setup)

### Docker vs Local Development
- **Docker Pros**: Isolated environment, consistent versions, easier setup
- **Docker Cons**: Slightly slower file system performance on macOS
- **Local Pros**: Faster performance, direct system access
- **Local Cons**: Version management complexity, PostgreSQL setup required

### Testing Strategy
- LiveView integration tests for real-time features
- Unit tests for media URL parsing
- GenServer state management tests
- Browser-based E2E tests for synchronization

### Performance Considerations
- Room servers are globally registered GenServers (one per active room)
- PubSub used for all real-time communications
- Client-side debouncing for video progress updates
- Asset pipeline optimized for production deployment

### Security Considerations
- Guest user system (no authentication required)
- Host-only controls for room management
- URL validation for media sources
- CSRF protection on all forms

## Troubleshooting

### Docker Issues
- **Port conflicts**: Change port mapping in docker-compose.yml
- **Slow builds**: Use `docker-compose up --build` only when dependencies change
- **Permission issues**: Ensure Docker has proper file system access
- **Memory issues**: Increase Docker Desktop resource limits

### Application Issues
- **Database connection**: Verify PostgreSQL container health
- **Asset loading**: Run `mix assets.build` or rebuild container
- **Video sync issues**: Check browser console for JavaScript errors
- **Queue not advancing**: Verify RoomServer logs for timer issues