# Quick Reference

## Start the App

```bash
# Docker (easiest)
docker-compose up

# Local
mix phx.server
```

## Rebuild Assets

```bash
# In Docker
docker-compose exec web mix assets.build

# Local
mix assets.build
```

## After Code Changes

1. Rebuild assets (command above)
2. Hard refresh browser: `Ctrl + Shift + R`

## Testing Queue

1. Create/join a room
2. Add 2-3 videos
3. Let first one finish
4. Should auto-advance!

## Logs to Watch

**Browser console (F12):**
```
MediaPlayer mounted: youtube Host: true
=== VIDEO ENDED ===
```

**Server logs:**
```
[info] 🎬 VIDEO ENDED - Host: true
[info] 🚀 Advancing to next track...
```

## Common Issues

| Problem | Solution |
|---------|----------|
| Queue not advancing | Hard refresh (Ctrl+Shift+R) |
| Old JavaScript cached | Clear cache or use incognito |
| Not host | Create your own room |
| Assets not updating | Run rebuild command above |

## URLs for Testing

**Short YouTube videos:**
- https://www.youtube.com/watch?v=zGDzdps75ns (10 sec)
- https://www.youtube.com/watch?v=MLwH4NUjAPg

**SoundCloud:**
- Paste any valid SoundCloud track URL
