# 🎵 SoundCloud Integration Testing Guide

## Quick Start

1. **Start the application:**
   ```bash
   ./start.sh
   ```

2. **Test SoundCloud embeds in isolation:**
   Open http://localhost:4000/test_soundcloud.html in your browser

3. **Run diagnostics:**
   ```bash
   chmod +x diagnose_soundcloud.sh
   ./diagnose_soundcloud.sh
   ```

## Testing in the App

### Step 1: Create or Join a Room
- Go to http://localhost:4000
- Click "Create Room" or join the demo room

### Step 2: Add SoundCloud Tracks
- Click the queue button (☰) in the top right
- Paste any of these test URLs:
  - `https://soundcloud.com/odesza/say-my-name-feat-zyra`
  - `https://soundcloud.com/rickastley/never-gonna-give-you-up-4`
  - `https://soundcloud.com/flume/flume-holdin-on`
  - `https://soundcloud.com/porter-robinson/shelter`

### Step 3: Verify Playback
- The SoundCloud player should appear with an orange gradient background
- The track should start playing automatically if you're the host
- When the track ends, it should auto-advance to the next item in queue

## Debugging

### Browser Console
Press F12 and check the Console tab for:
- "MediaPlayer mounted - Type: soundcloud"
- "SoundCloud API loaded successfully"
- "SoundCloud widget ready"
- Any error messages

### Common Issues

#### Player shows "Something went wrong"
- The track might not allow embedding
- Try a different SoundCloud URL
- Check if the track is publicly accessible

#### Player doesn't auto-advance
- Only the room host can control playback
- Check if you see "Host: true" in the console
- The host badge should appear next to your username

#### Player doesn't load at all
- Clear browser cache (Ctrl+Shift+R or Cmd+Shift+R)
- Check if JavaScript is enabled
- Try a different browser

## Testing URLs

### Working SoundCloud URLs:
```
https://soundcloud.com/odesza/say-my-name-feat-zyra
https://soundcloud.com/rickastley/never-gonna-give-you-up-4
https://soundcloud.com/flume/flume-holdin-on
https://soundcloud.com/porter-robinson/shelter
https://soundcloud.com/forss/flickermood
```

### YouTube URLs (should still work):
```
https://www.youtube.com/watch?v=dQw4w9WgXcQ
https://youtu.be/dQw4w9WgXcQ
dQw4w9WgXcQ
```

## API Testing

The test page at `/test_soundcloud.html` includes:
1. Visual player test
2. Classic waveform player test
3. Dynamic URL embedding test
4. Widget API control test (Play/Pause/Get Info)

## Implementation Details

### Backend
- `RoomLive.Show.parse_media_url/1` - Detects media type
- `RoomLive.Show.extract_soundcloud_data/1` - Parses SoundCloud URLs
- `RoomServer` - Manages mixed media queue

### Frontend
- `MediaPlayer` hook - Handles both YouTube and SoundCloud
- Auto-loads SoundCloud Widget API when needed
- Binds to FINISH event for auto-advance

### Embed URL Format
```
https://w.soundcloud.com/player/?
  url={encoded_track_url}&
  color=%23ff5500&
  auto_play=false&
  hide_related=true&
  show_comments=false&
  show_user=true&
  show_reposts=false&
  show_teaser=false&
  visual=true
```

## Visual Design

When a SoundCloud track is playing:
- Orange gradient background (from #ff5500 to #ff8800)
- Centered player with rounded corners
- Shadow effect for depth
- Visual mode for better aesthetics

## Mixed Queue

The queue supports both YouTube and SoundCloud:
- YouTube videos show with red "YT" badge
- SoundCloud tracks show with orange "SC" badge
- Both types can be mixed in the same queue
- Auto-advance works across both media types

## Success Indicators

You'll know it's working when:
1. ✅ SoundCloud URLs are accepted in the queue input
2. ✅ Orange "SC" badges appear on SoundCloud tracks
3. ✅ The player shows with gradient background
4. ✅ Tracks play and auto-advance
5. ✅ Console shows "SoundCloud widget ready"

## Need Help?

1. Check the browser console (F12)
2. Run `./diagnose_soundcloud.sh`
3. Test with the standalone page: `/test_soundcloud.html`
4. Try different SoundCloud URLs
5. Clear cache and restart the server