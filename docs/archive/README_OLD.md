# YouTube Video Chat App

A real-time video synchronization and chat application built with Phoenix LiveView.

## Features

- 🎥 YouTube video synchronization across multiple users
- 🎵 SoundCloud track synchronization
- 💬 Real-time chat
- 📋 Queue management system
- 👥 Presence tracking
- 🔄 Automatic video advancement

## Quick Start

### Prerequisites

- Elixir 1.17+ and OTP 27+
- PostgreSQL
- Node.js (for assets)

### Development Setup

```bash
# Install dependencies
mix deps.get
cd assets && npm install && cd ..

# Setup database
mix ecto.setup

# Start the server
mix phx.server
```

Visit `http://localhost:4000`

### Docker Setup

```bash
# Build and start
docker-compose up --build
```

## Documentation

- [Getting Started](docs/GETTING_STARTED.md)
- [Docker Setup](docs/setup/docker.md)
- [Queue System](docs/features/queue-system.md)
- [Development Guides](docs/development/)

## Project Structure

```
├── lib/                    # Application code
│   ├── youtube_video_chat_app/      # Business logic
│   └── youtube_video_chat_app_web/  # Web interface
├── assets/                 # Frontend assets
│   ├── js/                # JavaScript
│   └── css/               # Stylesheets
├── priv/                  # Static files and migrations
├── test/                  # Tests
├── scripts/               # Utility scripts
└── docs/                  # Documentation
```

## License

[Your License Here]
