# Queue System Test Guide

## Testing the Fixed Auto-Advance System

### Prerequisites
1. Start the application: `mix phx.server` or `docker-compose up`
2. Open http://localhost:4000
3. Create a new room
4. Have the room URL ready for testing

### Test Case 1: YouTube Auto-Advance
1. **Add YouTube videos to queue:**
   - Paste: `https://www.youtube.com/watch?v=dQw4w9WgXcQ` (Rick Roll - 3:32)
   - Paste: `https://www.youtube.com/watch?v=jNQXAC9IVRw` (Me at the zoo - 0:19)
   - Paste: `https://www.youtube.com/watch?v=kJQP7kiw5Fk` (Despacito - 4:42)

2. **Expected behavior:**
   - First video should start playing immediately
   - Queue should show 2 videos waiting
   - After Rick Roll ends (~3:32), it should auto-advance to "Me at the zoo"
   - After "Me at the zoo" ends (~19s), it should auto-advance to "Despacito"

### Test Case 2: SoundCloud Auto-Advance
1. **Add SoundCloud tracks:**
   - Paste: `https://soundcloud.com/forss/flickermood`
   - Paste: `https://soundcloud.com/shura/indecision-1`

2. **Expected behavior:**
   - First track should start playing
   - After track finishes, should auto-advance to next SoundCloud track

### Test Case 3: Mixed Media Auto-Advance
1. **Mix YouTube and SoundCloud:**
   - Add YouTube video (short): `https://www.youtube.com/watch?v=jNQXAC9IVRw`
   - Add SoundCloud track: `https://soundcloud.com/forss/flickermood`
   - Add another YouTube video: `https://www.youtube.com/watch?v=dQw4w9WgXcQ`

2. **Expected behavior:**
   - Should seamlessly transition between different media types
   - Each transition should reload the iframe with new media

### Test Case 4: Manual Skip
1. **As host:**
   - Add multiple videos to queue
   - Click "Skip ⏭" button while video is playing
   - Should immediately advance to next video

### Debugging Features
Check browser console for detailed logs:
- `[YouTube]` - YouTube player events and end detection
- `[SoundCloud]` - SoundCloud player events
- `[MediaPlayer]` - General media player state changes
- `[RoomServer]` - Server-side queue management (check server logs)

### Expected Console Output
When auto-advance works correctly, you should see:
```
[YouTube] 🎬🎬🎬 VIDEO ENDED - ADVANCING TO NEXT 🎬🎬🎬
[YouTube] 📤 Sending video_ended event to server
[MediaPlayer] === RELOADING MEDIA ===
[MediaPlayer] New type: youtube
[MediaPlayer] Loading YouTube URL: ...
```

### Issues to Watch For
- ❌ Video ends but doesn't advance (check host status)
- ❌ Queue shows wrong count
- ❌ Multiple rapid advances (duplicate events)
- ❌ Audio continues from previous video
- ❌ UI doesn't update to show new media

### Manual Testing Checklist
- [ ] YouTube videos auto-advance after ending
- [ ] SoundCloud tracks auto-advance after ending
- [ ] Mixed media types work together
- [ ] Queue updates properly show remaining items
- [ ] Manual skip works for host
- [ ] Non-host users see media changes
- [ ] No audio overlaps between tracks
- [ ] UI properly shows "Now Playing" vs "Up Next"