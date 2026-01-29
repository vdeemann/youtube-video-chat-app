# YouTube Video Chat App

A real-time video chat application supporting YouTube videos and SoundCloud tracks with queue management.

## 📚 Documentation

**NEW!** Complete line-by-line code documentation is now available:
- **[Code Documentation](./docs/code-documentation/README.md)** - Comprehensive guides for every file
- **[Getting Started](./docs/code-documentation/INDEX.md)** - Navigation and learning paths
- **[Architecture Overview](./docs/code-documentation/00-OVERVIEW.md)** - System design and tech stack

Perfect for:
- 🎓 Learning Elixir, Phoenix, and LiveView
- 👨‍💻 Onboarding new developers
- 🔍 Understanding the codebase in depth

## Features

- 🎥 YouTube video playback
- 🎵 SoundCloud track playback
- 📋 Queue system with auto-advancement
- 💬 Real-time chat
- 👥 Multi-user rooms
- 🎭 Live presence tracking

## Quick Start

### Using Docker (Recommended)

```bash
docker-compose up
```

Then open: http://localhost:4000

### Local Development

**Requirements:**
- Elixir 1.14+
- PostgreSQL
- Node.js & npm

**Setup:**
```bash
# Install dependencies
mix deps.get
cd assets && npm install && cd ..

# Setup database
mix ecto.create
mix ecto.migrate

# Start server
mix phx.server
```

Open: http://localhost:4000

## How It Works

### Queue System

1. **Add media** - Paste a YouTube or SoundCloud URL
2. **Auto-play** - First item starts playing immediately
3. **Auto-advance** - When media ends, automatically plays next item
4. **Host control** - Only the room host triggers advancement

### Supported URLs

**YouTube:**
- `https://youtube.com/watch?v=...`
- `https://youtu.be/...`

**SoundCloud:**
- `https://soundcloud.com/artist/track`

## Project Structure

```
├── assets/              # Frontend assets
│   ├── js/
│   │   └── hooks/       # LiveView hooks
│   │       └── media_player.js  # Queue & playback logic
│   └── css/
├── lib/
│   ├── youtube_video_chat_app/
│   │   └── rooms/
│   │       └── room_server.ex   # Queue management
│   └── youtube_video_chat_app_web/
│       └── live/
│           └── room_live/       # LiveView UI
├── config/              # Configuration
├── priv/               # Static files & migrations
├── docs/
│   └── code-documentation/  # 📚 Line-by-line code explanations
└── test/               # Tests
```

## Development

### Run Tests
```bash
mix test
```

### Rebuild Assets
```bash
# In Docker
docker-compose exec web mix assets.build

# Locally
mix assets.build
```

### Access Database
```bash
# In Docker
docker-compose exec db psql -U postgres -d youtube_video_chat_app_dev

# Locally
psql youtube_video_chat_app_dev
```

## Troubleshooting

### Queue not advancing?

1. **Hard refresh browser** - Press `Ctrl+Shift+R`
2. **Check you're the host** - Create your own room
3. **Open console** - Press F12 and look for "VIDEO ENDED"
4. **Rebuild assets** - Run `docker-compose exec web mix assets.build`

### bcrypt_elixir error?

Use Docker - it handles all compilation automatically:
```bash
docker-compose up
```

### Port already in use?

```bash
# Stop containers
docker-compose down

# Or kill local processes
mix phx.server  # then Ctrl+C
```

## Documentation

Full documentation is in the `docs/` directory:
- **`docs/code-documentation/`** - 📚 **NEW!** Complete line-by-line code explanations
- `docs/features/` - Feature documentation
- `docs/setup/` - Setup guides
- `docs/development/` - Development notes

## Tech Stack

- **Backend:** Elixir + Phoenix + LiveView
- **Frontend:** JavaScript (ES6) + TailwindCSS
- **Database:** PostgreSQL
- **Real-time:** Phoenix PubSub + WebSockets
- **Media:** YouTube iframe API + SoundCloud Widget API

## License

MIT

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

---

**Built with ❤️ using Phoenix LiveView**
