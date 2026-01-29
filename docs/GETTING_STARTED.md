# 🚀 QUICK START - Fix & Run Your YouTube Watch Party App

Since Docker isn't running, let's use **Elixir 1.17** which works perfectly with Phoenix.

## Option 1: One-Click Fix (Recommended)
```bash
chmod +x fix.sh
./fix.sh
```

This script will:
- ✅ Install Elixir 1.17 (if needed)
- ✅ Clean and reinstall dependencies
- ✅ Compile everything
- ✅ Setup the database
- ✅ Start your app

## Option 2: Manual Homebrew Install
```bash
# 1. Downgrade Elixir
brew uninstall --ignore-dependencies elixir
brew install elixir@1.17
brew link --overwrite elixir@1.17

# 2. Clean everything
rm -rf _build deps mix.lock

# 3. Reinstall and compile
mix local.hex --force
mix deps.get
mix compile

# 4. Setup database
mix ecto.setup

# 5. Start server
mix phx.server
```

## Option 3: Use asdf Version Manager
```bash
chmod +x install_asdf_elixir.sh
./install_asdf_elixir.sh
```

## 🎮 After It's Running

Visit: **http://localhost:4000**

You'll have:
- 🎬 Synchronized YouTube video playback
- 💬 Instagram Live-style floating comments
- 🎵 Video queue management
- 👥 Real-time presence tracking

## 📺 How to Use

1. **Create a Room** - Click "Create New Room"
2. **Share the Link** - Send room URL to friends
3. **Add Videos** - Paste YouTube URLs
4. **Chat** - Type messages that float across the video
5. **Customize** - Adjust chat opacity and speed

## 🆘 Troubleshooting

### PostgreSQL Not Running?
```bash
# Start PostgreSQL
brew services start postgresql@14

# Or if you have a different version
brew services start postgresql
```

### Port 4000 Already in Use?
```bash
# Find and kill the process
lsof -i :4000
kill -9 <PID>
```

### Still Having Issues?
```bash
# Nuclear option - clean everything
rm -rf _build deps mix.lock ~/.hex ~/.mix
./fix.sh
```

## 📝 Note

The issue is that **Elixir 1.18.x broke Phoenix 1.7.x**. By using Elixir 1.17, everything works perfectly. This is the simplest solution without Docker.

---

**Just run `./fix.sh` and you'll be watching YouTube with friends in 2 minutes!** 🎉
