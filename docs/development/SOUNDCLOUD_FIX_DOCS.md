# SoundCloud Playback Fix Documentation

## Problem
SoundCloud tracks were not playing when the play button was clicked in the embedded player.

## Root Causes Identified

1. **Missing auto_play parameter**: The SoundCloud embed URL was missing `auto_play=true`, which is needed for the track to start playing when loaded
2. **Widget API initialization issues**: The SoundCloud Widget API wasn't always loading or initializing properly
3. **Race conditions**: The widget setup was sometimes happening before the iframe was fully loaded

## Fixes Applied

### 1. Backend Fix (show.ex)
- Changed `auto_play=false` to `auto_play=true` in the SoundCloud embed URL generation
- This ensures tracks start playing automatically when loaded

```elixir
embed_url = "https://w.soundcloud.com/player/?url=#{encoded_url}&color=%23ff5500&auto_play=true&..."
```

### 2. Frontend Fixes (media_player.js)

#### Improved API Loading
- Added retry logic if the SoundCloud API fails to load
- Better detection of when the API is actually ready
- Timeout handling to prevent infinite waiting

#### Enhanced Widget Initialization
- Added `widgetReady` flag to prevent duplicate initialization
- Unbind existing events before binding new ones to prevent duplicates
- Manual fallback to check widget state if ready event doesn't fire

#### Better Error Recovery
- If an error occurs, automatically retry playing the track
- Added detailed console logging for debugging
- Graceful handling of widget destruction

## How to Apply the Fix

### Option 1: Quick Fix (Recommended)
Double-click `fix-soundcloud-windows.bat` or run:
```powershell
.\fix-soundcloud-windows.ps1
```

### Option 2: Manual Steps
1. Stop Docker containers: `docker-compose down`
2. Rebuild the web container: `docker-compose build web`
3. Start the app: `docker-compose up`

## Testing the Fix

1. Create or join a room
2. Add a SoundCloud URL to the queue (e.g., `https://soundcloud.com/artist/track-name`)
3. The track should:
   - Display with an orange gradient background
   - Show the SoundCloud player widget
   - **Start playing automatically** when it becomes the current media
   - Auto-advance to the next item when finished

## Browser Console Debugging

To debug SoundCloud issues, open browser DevTools (F12) and look for these messages:

### Success Messages:
- `SoundCloud API loaded successfully`
- `SoundCloud widget READY event fired`
- `SoundCloud track PLAYING`
- `Current SoundCloud track: [track name]`

### Error Messages to Watch For:
- `Failed to load SoundCloud API` - API script couldn't be loaded
- `SoundCloud player ERROR` - Track might be private or deleted
- `Widget ready event hasn't fired` - Initialization timeout

## Common Issues and Solutions

### Issue: Track still won't play
**Solution**: 
- Check if the track is publicly available and allows embedding
- Try a different SoundCloud URL
- Clear browser cache and reload the page

### Issue: "This track is not streamable"
**Solution**: 
- The track owner has disabled embedding
- Try a different track that allows external playback

### Issue: Widget loads but no sound
**Solution**:
- Check browser audio permissions
- Ensure volume is not muted (both in player and system)
- Try refreshing the page

### Issue: Auto-advance not working
**Solution**:
- Only the room host can control playback
- Check if you're the host (purple "Skip" button visible)
- Check console for "SoundCloud track FINISHED" message

## Technical Details

### SoundCloud Widget API Events
The app listens for these events:
- `SC.Widget.Events.READY` - Widget is loaded and ready
- `SC.Widget.Events.PLAY` - Track started playing
- `SC.Widget.Events.PAUSE` - Track was paused
- `SC.Widget.Events.FINISH` - Track ended (triggers auto-advance)
- `SC.Widget.Events.ERROR` - An error occurred

### Embed URL Parameters
```
auto_play=true       // Auto-start playback
color=%23ff5500     // Orange theme color
visual=true         // Show waveform visualization
show_comments=false // Hide comments
show_user=true      // Show artist info
show_reposts=false  // Hide repost count
```

## Additional Notes

- SoundCloud integration works alongside YouTube videos
- Both media types can be mixed in the same queue
- The app automatically switches between YouTube and SoundCloud players
- No API keys are required - uses public embed functionality

## Need More Help?

If issues persist after applying the fix:
1. Run `.\troubleshoot-windows.ps1` for system diagnostics
2. Check Docker logs: `docker-compose logs web`
3. Try a fresh rebuild: `docker-compose down -v && docker-compose up --build`