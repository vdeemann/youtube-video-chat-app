# 🐳 DOCKER SETUP GUIDE - YouTube Watch Party App

## 🚀 Quick Start (2 Steps)

### Step 1: Install & Start Docker
```bash
chmod +x install_and_run_docker.sh
./install_and_run_docker.sh
```

This script will:
- ✅ Check if Docker is installed (install if needed)
- ✅ Start Docker Desktop
- ✅ Launch your app

### Step 2: Visit Your App
Open: **http://localhost:4000**

That's it! 🎉

---

## 📦 What You Get With Docker

### Perfect Isolation
- ✅ Elixir 1.17.3 (Phoenix 1.7 compatible)
- ✅ PostgreSQL 15
- ✅ Node.js for assets
- ✅ All in isolated containers
- ✅ Won't conflict with other projects

### Development Features
- 🔥 **Hot code reloading** - Changes appear instantly
- 📁 **Code syncing** - Edit files locally, runs in Docker
- 🗄️ **Persistent database** - Data survives restarts
- 📊 **Logs visible** - See all output in terminal

---

## 🎮 Docker Commands Cheat Sheet

### Basic Operations
```bash
# Start the app (foreground - see logs)
docker-compose up

# Start the app (background)
docker-compose up -d

# Stop the app
docker-compose down

# View logs
docker-compose logs -f

# Restart after code changes
docker-compose restart web
```

### Advanced Operations
```bash
# Rebuild after dependency changes
docker-compose up --build

# Access Elixir console
docker-compose exec web iex -S mix

# Run mix commands
docker-compose exec web mix ecto.migrate
docker-compose exec web mix test

# Access PostgreSQL
docker-compose exec db psql -U postgres

# Clean everything (nuclear option)
docker-compose down -v --remove-orphans
```

---

## 🏗️ Project Structure

```
youtube-video-chat-app/
├── docker-compose.yml    # Orchestrates containers
├── Dockerfile.dev        # Development container
├── Dockerfile           # Production container (for deployment)
├── .dockerignore        # Speed up builds
└── Your Phoenix app files...
```

---

## 🔧 Troubleshooting

### "Cannot connect to Docker daemon"
```bash
# Docker isn't running. Start it:
open -a Docker

# Wait for whale icon in menu bar, then:
docker-compose up
```

### Port 4000 already in use
```bash
# Find what's using it
lsof -i :4000

# Kill it
kill -9 <PID>

# Or use different port in docker-compose.yml:
# Change "4000:4000" to "4001:4000"
# Then visit http://localhost:4001
```

### Changes not appearing
```bash
# Rebuild the container
docker-compose down
docker-compose up --build
```

### Database errors
```bash
# Reset database
docker-compose exec web mix ecto.drop
docker-compose exec web mix ecto.create
docker-compose exec web mix ecto.migrate
```

### Slow performance on Mac
Docker Desktop > Preferences > Resources > Advanced
- Increase CPUs to 4+
- Increase Memory to 8GB+

---

## 🚀 Your App Features

Once running, you have:
- 🎬 **Synchronized YouTube playback**
- 💬 **Instagram Live-style floating comments**
- 🎵 **DJ-style video queue**
- 👥 **Real-time presence tracking**
- 🎨 **Customizable chat appearance**

---

## 💡 Why Docker for Multiple Projects?

### Your Setup
```
~/youtube-video-chat-app/
  docker-compose up        # Uses Elixir 1.17.3
  
~/another-phoenix-app/
  docker-compose up        # Can use Elixir 1.18.2
  
~/legacy-app/
  docker-compose up        # Can use Elixir 1.14
```

All running simultaneously, no conflicts! Each project is completely isolated.

---

## 🎯 Next Steps

1. **Create a room** - Click "Create New Room"
2. **Share the link** - Send to friends
3. **Add YouTube videos** - Paste URLs in the queue
4. **Start chatting** - Messages float across the video!

---

## 📝 Notes

- **First run** takes 2-3 minutes (building images)
- **Subsequent runs** take seconds
- **Code changes** appear instantly (hot reload)
- **Database persists** between restarts
- **Completely isolated** from your system

---

## 🆘 Need Help?

If Docker isn't working, you can always fallback to local Elixir:
```bash
brew install elixir@1.17
brew link --overwrite elixir@1.17
mix deps.get
mix phx.server
```

But Docker is better for multiple projects! 🐳
