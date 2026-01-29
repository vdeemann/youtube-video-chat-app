# Queue System Documentation

## Current Behavior (Working As Designed)

The queue system operates with the following logic:

### When Adding Media:
1. **First media added**: Starts playing immediately (goes to "NOW PLAYING")
2. **Subsequent media**: Added to "UP NEXT" queue

### When Video Ends:
1. **Completed video**: Removed from display entirely
2. **Next in queue**: Moves from "UP NEXT" to "NOW PLAYING"
3. **Queue updates**: All users see the same state

### Visual Flow:
```
Initial State:
┌─────────────────┐
│ NOW PLAYING     │
│ Video A         │
└─────────────────┘
┌─────────────────┐
│ UP NEXT         │
│ 1. Video B      │
│ 2. Video C      │
└─────────────────┘

After Video A ends:
┌─────────────────┐
│ NOW PLAYING     │
│ Video B         │  ← Video B moved here
└─────────────────┘
┌─────────────────┐
│ UP NEXT         │
│ 1. Video C      │  ← Video C moved up
└─────────────────┘
(Video A is gone)
```

## Is This A Problem?

The queue is functioning correctly if:
- ✅ Videos auto-advance when ending
- ✅ Next video starts playing automatically
- ✅ Queue updates properly
- ✅ All users see the same queue state

The only "issue" is that completed videos disappear. This is intentional to keep the interface clean.

## Potential Enhancements

### Option 1: Play History
Add a "Recently Played" section showing the last 5-10 completed tracks:
```
┌─────────────────┐
│ RECENTLY PLAYED │
│ • Video A ✓     │
│ • Video Z ✓     │
└─────────────────┘
```

### Option 2: Completed Badge
Mark completed videos but keep them visible:
```
┌─────────────────┐
│ NOW PLAYING     │
│ Video B         │
└─────────────────┘
┌─────────────────┐
│ COMPLETED       │
│ ✓ Video A       │
└─────────────────┘
```

### Option 3: Loop Mode
Add option to re-queue completed videos automatically.

## Debugging Queue Issues

### Check Server Logs
Look for these messages when a video ends:
```
[MediaPlayer] VIDEO ENDED - ADVANCING TO NEXT
[RoomServer] PLAY NEXT CALLED
[RoomServer] Advancing to next track: [title]
[RoomServer] Broadcasting media change
[RoomServer] Broadcasting queue update
```

### Common Issues

1. **Videos not advancing**
   - Check if you're the host (only host can advance)
   - Verify JavaScript console for errors
   - Ensure browser allows autoplay

2. **Queue not updating**
   - Check WebSocket connection
   - Verify PubSub subscriptions
   - Look for broadcast messages in logs

3. **Duplicate videos**
   - Database sync issue
   - Clear browser cache
   - Restart Phoenix server

## Testing Queue Behavior

1. **Basic Test**
   ```
   1. Add 3 YouTube videos rapidly
   2. First should play immediately
   3. Other 2 should appear in UP NEXT
   4. Let first video end
   5. Second should start automatically
   ```

2. **Stress Test**
   ```
   1. Add 10+ videos to queue
   2. Use Skip button to advance rapidly
   3. Verify queue updates correctly
   4. Check all users see same state
   ```

3. **Mixed Media Test**
   ```
   1. Add YouTube video
   2. Add SoundCloud track
   3. Add another YouTube video
   4. Verify transitions work between platforms
   ```

## Configuration

The queue behavior is controlled in:
- `lib/youtube_video_chat_app/rooms/room_server.ex` - Queue logic
- `lib/youtube_video_chat_app_web/live/room_live/show.ex` - UI updates
- `assets/js/hooks/media_player.js` - End detection

To modify behavior, adjust the `play_next` function in `room_server.ex`.
