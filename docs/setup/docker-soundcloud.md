# 🐳 Docker SoundCloud Integration Guide

## Quick Start (Docker)

### Option 1: Full Rebuild (Recommended First Time)
```bash
chmod +x docker_soundcloud_deploy.sh
./docker_soundcloud_deploy.sh
```
This will:
- Stop containers
- Rebuild with all SoundCloud changes
- Start containers
- Wait for app to be ready

### Option 2: Quick Restart (For Updates)
```bash
chmod +x docker_quick_restart.sh
./docker_quick_restart.sh
```
This will:
- Rebuild JavaScript assets
- Restart web container
- Keep database running

## Testing SoundCloud Integration

### 1. Check Everything is Working
```bash
chmod +x docker_soundcloud_check.sh
./docker_soundcloud_check.sh
```

### 2. Test Standalone Player
Open in browser: http://localhost:4000/test_soundcloud.html

You should see:
- 4 different SoundCloud players
- All should be playable
- Widget API controls should work

### 3. Test in Main App
1. Go to http://localhost:4000
2. Create or join a room
3. Click the queue button (☰) in top right
4. Add these test URLs:
   ```
   https://soundcloud.com/odesza/say-my-name-feat-zyra
   https://soundcloud.com/rickastley/never-gonna-give-you-up-4
   https://soundcloud.com/flume/flume-holdin-on
   ```

## Docker Commands

### View Logs
```bash
# All logs
docker-compose logs -f web

# SoundCloud-specific logs
chmod +x docker_sc_logs.sh
./docker_sc_logs.sh
```

### Container Management
```bash
# Check status
docker-compose ps

# Restart web container
docker-compose restart web

# Stop everything
docker-compose down

# Start everything
docker-compose up -d
```

### Debugging Inside Container
```bash
# Open shell in web container
docker-compose exec web bash

# Check if MediaPlayer hook is compiled
docker-compose exec web grep -c "MediaPlayer" priv/static/assets/app.js

# Test URL parsing
docker-compose exec web elixir -e 'IO.puts("SoundCloud" in "https://soundcloud.com/test")'
```

## Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose logs web

# Rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up
```

### JavaScript changes not showing
```bash
# Rebuild assets inside container
docker-compose exec web mix assets.build

# Or do a full rebuild
./docker_soundcloud_deploy.sh
```

### Database issues
```bash
# Reset database
docker-compose exec web mix ecto.reset

# Or completely fresh start
docker-compose down -v
docker-compose up
```

### Port 4000 already in use
```bash
# Find what's using port 4000
lsof -i :4000

# Kill it (replace PID with actual process ID)
kill -9 PID

# Or change port in docker-compose.yml
# Change "4000:4000" to "4001:4000"
```

## File Locations in Container

- App code: `/app`
- Compiled JS: `/app/priv/static/assets/app.js`
- Test page: `/app/priv/static/test_soundcloud.html`
- Logs: `docker-compose logs web`

## How It Works

1. **Backend** (`/app/lib/youtube_video_chat_app_web/live/room_live/show.ex`)
   - Parses SoundCloud URLs
   - Generates embed URLs
   - Manages mixed media queue

2. **Frontend** (`/app/lib/youtube_video_chat_app_web/live/room_live/show.html.heex`)
   - Displays SoundCloud player with gradient background
   - Shows media type badges (SC/YT)
   - Handles both media types

3. **JavaScript** (`/app/assets/js/hooks/media_player.js`)
   - Loads SoundCloud Widget API
   - Detects track end for auto-advance
   - Manages both YouTube and SoundCloud

## Success Checklist

✅ Docker containers running (`docker-compose ps`)
✅ App accessible at http://localhost:4000
✅ Test page works: http://localhost:4000/test_soundcloud.html
✅ SoundCloud URLs accepted in queue
✅ Orange "SC" badges appear on SoundCloud tracks
✅ Gradient background shows for SoundCloud player
✅ Tracks auto-advance when finished (host only)
✅ Browser console shows "SoundCloud widget ready"

## Common Issues

### "Something went wrong" in SoundCloud player
- Track doesn't allow embedding
- Try a different SoundCloud URL
- Check if track is public

### Player doesn't auto-advance
- Only room host can control playback
- Check console for "Host: true"
- Try creating a new room (you'll be host)

### Changes not appearing
- Run `./docker_quick_restart.sh`
- Clear browser cache (Ctrl+Shift+R)
- Check logs: `docker-compose logs -f web`

## Need Help?

1. Run diagnostics: `./docker_soundcloud_check.sh`
2. Check logs: `./docker_sc_logs.sh`
3. Test standalone: http://localhost:4000/test_soundcloud.html
4. Browser console: F12 → Console tab
5. Full rebuild: `./docker_soundcloud_deploy.sh`