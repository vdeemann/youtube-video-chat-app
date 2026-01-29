# Test URLs for Queue System

## YouTube Test URLs

### Short Videos (Good for Testing Auto-Advance)
```
https://www.youtube.com/watch?v=aqz-KE-bpKQ
https://www.youtube.com/watch?v=FTQbiNvZqaY
https://www.youtube.com/watch?v=tPEE9ZwTmy0
```

### Music Videos
```
https://www.youtube.com/watch?v=QDYfEBY9NM4
https://www.youtube.com/watch?v=60ItHLz5WEA
https://www.youtube.com/watch?v=fJ9rUzIMcZQ
```

### Tech Videos
```
https://www.youtube.com/watch?v=LXb3EKWsInQ
https://www.youtube.com/watch?v=Gk-KBpQG5nM
```

## SoundCloud Test URLs

### Electronic/Dance
```
https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew
https://soundcloud.com/ncsounds/jim-yosef-link-ncs-release
https://soundcloud.com/martingarrix/martin-garrix-feat-bonn-high-on-life
```

### Indie/Alternative
```
https://soundcloud.com/mrsuicidesheep/vancouver-sleep-clinic-someone-to-stay
https://soundcloud.com/kodaline/all-i-want-part-1
```

### Hip-Hop/Rap
```
https://soundcloud.com/chancetherapper/acid-rain-1
https://soundcloud.com/macklemore/cant-hold-us-feat-ray-dalton
```

## Mixed Queue Test Sequence

Perfect for testing the queue system with variety:

1. **YouTube Short** (30 seconds)
   ```
   https://www.youtube.com/watch?v=aqz-KE-bpKQ
   ```

2. **SoundCloud Track** (3-4 minutes)
   ```
   https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew
   ```

3. **YouTube Music** (3-4 minutes)
   ```
   https://www.youtube.com/watch?v=60ItHLz5WEA
   ```

4. **SoundCloud Electronic** (3-4 minutes)
   ```
   https://soundcloud.com/martingarrix/martin-garrix-feat-bonn-high-on-life
   ```

5. **YouTube Short** (1 minute)
   ```
   https://www.youtube.com/watch?v=FTQbiNvZqaY
   ```

## Quick Copy-Paste List

Just copy these one at a time to quickly build a test queue:

```
https://www.youtube.com/watch?v=aqz-KE-bpKQ
https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew
https://www.youtube.com/watch?v=60ItHLz5WEA
https://soundcloud.com/ncsounds/jim-yosef-link-ncs-release
https://www.youtube.com/watch?v=tPEE9ZwTmy0
```

## Testing Scenarios

### 1. Basic Queue Test
- Add 3 videos
- Let first play for 10 seconds
- Skip to next (if host)
- Let second play to end
- Verify third starts automatically

### 2. Mixed Media Test
- Add YouTube video
- Add SoundCloud track
- Add another YouTube video
- Verify smooth transitions between platforms

### 3. Synchronization Test
- Open in two browsers
- Add videos in Browser A
- Verify Browser B shows same queue
- Skip in Browser A
- Verify Browser B updates

### 4. Edge Cases
- Add to empty queue (should start immediately)
- Remove currently playing (should advance)
- Remove last in queue (should show empty)
- Add while playing (should queue)

### 5. Stress Test
- Add 10+ tracks rapidly
- Skip through them quickly
- Remove random tracks
- Verify queue stays synchronized

## Console Commands for Testing

Open browser console (F12) and monitor:

```javascript
// Check current queue state
console.log("Checking queue state...");

// Monitor SoundCloud events
if (window.SC && window.SC.Widget) {
  const widget = SC.Widget(document.getElementById('soundcloud-iframe'));
  widget.isPaused(paused => console.log('SoundCloud paused:', paused));
  widget.getDuration(dur => console.log('Duration:', dur));
}

// Monitor YouTube events
const iframe = document.getElementById('youtube-iframe');
if (iframe) {
  console.log('YouTube iframe found:', iframe.src);
}
```

## Expected Behavior

### When Adding Tracks
- First track starts immediately if nothing playing
- Subsequent tracks appear in "Up Next" section
- Queue badge shows count
- All users see the update

### During Playback
- "Now Playing" shows current track with animation
- Progress visible in player controls
- Console shows progress updates
- Track ends trigger auto-advance

### When Track Ends
- Current track removed from display
- Next track starts automatically
- Queue updates for all users
- Console shows "ENDED" or "FINISHED"

## Troubleshooting

### If Auto-Advance Fails
1. Check console for "ENDED" events
2. Verify you're the host
3. Try manual skip button
4. Check browser autoplay settings

### If Queue Not Syncing
1. Refresh both browsers
2. Check WebSocket connection
3. Verify same room URL
4. Check console for errors

### If Tracks Won't Play
1. Verify URLs are public
2. Check console for API errors
3. Try different tracks
4. Clear browser cache

---

Use these test URLs to thoroughly test the queue system. The short videos are perfect for testing auto-advance without waiting too long!