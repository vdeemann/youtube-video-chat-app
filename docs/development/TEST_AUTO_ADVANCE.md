# Testing Auto-Advance Queue System

## Quick Test URLs (Short Duration)

### 30-Second YouTube Videos
Perfect for quick testing without waiting long:

```
https://www.youtube.com/watch?v=aqz-KE-bpKQ
https://www.youtube.com/watch?v=Il-an3K9pjg
https://www.youtube.com/watch?v=2vjPBrBU-TM
```

### 1-Minute YouTube Videos
```
https://www.youtube.com/watch?v=FTQbiNvZqaY
https://www.youtube.com/watch?v=tPEE9ZwTmy0
```

### SoundCloud Test Tracks
```
https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew
https://soundcloud.com/ncsounds/jim-yosef-link-ncs-release
```

## Test Sequence 1: Basic Auto-Advance

**Goal:** Verify tracks advance automatically

1. Add this 30-second YouTube video:
   ```
   https://www.youtube.com/watch?v=aqz-KE-bpKQ
   ```

2. Add this SoundCloud track:
   ```
   https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew
   ```

3. Add another 30-second YouTube video:
   ```
   https://www.youtube.com/watch?v=Il-an3K9pjg
   ```

**Expected Results:**
- First video plays for 30 seconds
- Automatically switches to SoundCloud
- When SoundCloud ends, switches to last YouTube video
- Queue empties as tracks play

## Test Sequence 2: Rapid Testing

**Goal:** Quick verification with very short videos

1. Copy and paste these URLs one by one:
   ```
   https://www.youtube.com/watch?v=aqz-KE-bpKQ
   https://www.youtube.com/watch?v=Il-an3K9pjg
   https://www.youtube.com/watch?v=2vjPBrBU-TM
   ```

**Expected:** Each 30-second video plays and advances automatically

## Console Commands for Testing

### Monitor Current State
```javascript
// Check if MediaPlayer hook is loaded
console.log("MediaPlayer loaded:", window.liveSocket.hooks.MediaPlayer ? "YES" : "NO");

// Check current iframe
const yt = document.getElementById('youtube-iframe');
const sc = document.getElementById('soundcloud-iframe');
console.log("YouTube iframe:", yt ? yt.src : "Not found");
console.log("SoundCloud iframe:", sc ? sc.src : "Not found");
```

### Force End Event (Testing Only)
```javascript
// Simulate track ending (HOST ONLY)
document.querySelector('[phx-hook="MediaPlayer"]').__phoenix_hook__.pushEvent("video_ended", {});
```

### Check SoundCloud Widget
```javascript
// If SoundCloud is playing
if (window.SC && window.SC.Widget) {
  const widget = SC.Widget(document.getElementById('soundcloud-iframe'));
  widget.getDuration(d => console.log("Duration:", d/1000, "seconds"));
  widget.getPosition(p => console.log("Position:", p/1000, "seconds"));
  widget.isPaused(paused => console.log("Paused:", paused));
}
```

## Visual Test Checklist

### ✅ Auto-Advance Working:
- [ ] Track ends without user interaction
- [ ] Next track starts within 1-2 seconds
- [ ] "NOW PLAYING" updates to new track
- [ ] "UP NEXT" count decreases by 1
- [ ] Previous track removed from display
- [ ] Console shows "VIDEO_ENDED EVENT"
- [ ] Console shows "Playing next track"

### ❌ Auto-Advance NOT Working:
- [ ] Track ends but player stops
- [ ] Queue doesn't update
- [ ] Need to click Skip manually
- [ ] No console messages about ending
- [ ] "NOW PLAYING" stays the same
- [ ] Queue count doesn't change

## Browser Testing Matrix

Test in multiple browsers to ensure compatibility:

| Browser | Expected Result | Notes |
|---------|----------------|-------|
| Chrome | ✅ Full support | Best performance |
| Firefox | ✅ Full support | May need autoplay permission |
| Edge | ✅ Full support | Similar to Chrome |
| Safari | ⚠️ May need permission | Check autoplay settings |

## Multi-User Sync Test

**Goal:** Verify all users see synchronized queue

### Setup:
1. Open app in Browser A (host)
2. Open same room in Browser B (viewer)
3. Add tracks in Browser A

### Test:
1. Let track play to end in Browser A
2. Browser B should also advance
3. Both should show same "NOW PLAYING"
4. Both should show same queue

### Expected Console (Browser A - Host):
```
=== VIDEO_ENDED EVENT ===
Is host: true
Host triggering auto-advance
```

### Expected Console (Browser B - Viewer):
```
=== MEDIA_CHANGED received ===
=== QUEUE_UPDATED received ===
```

## Edge Case Testing

### Test 1: Single Track
- Add only one track
- Let it finish
- **Expected:** Shows "No media playing"

### Test 2: Remove Currently Playing
- Add 3 tracks
- While first is playing, add 2 more
- Remove the currently playing track
- **Expected:** Should advance to next

### Test 3: Skip vs Auto-Advance
- Add 3 tracks
- Click Skip on first
- Let second play to end
- **Expected:** Both should work

### Test 4: Mixed Media Types
- Alternate YouTube and SoundCloud
- **Expected:** Smooth transitions

## Performance Monitoring

### Check Memory Usage:
```javascript
// In Chrome DevTools
performance.memory
```

### Check Event Listeners:
```javascript
// See all event listeners
getEventListeners(document.getElementById('soundcloud-iframe'))
```

### Check WebSocket:
- F12 → Network → WS
- Should show active phoenix connection
- Look for messages when tracks change

## Common Issues During Testing

### Issue: "Not the host"
**Solution:** Look for purple Skip button to confirm host status

### Issue: "Track won't end"
**Solution:** Use 30-second test videos for faster testing

### Issue: "Console shows nothing"
**Solution:** Ensure you ran `fix-auto-advance.bat` and rebuilt

### Issue: "Works in Chrome but not Firefox"
**Solution:** Check autoplay permissions in Firefox settings

## Success Metrics

The auto-advance system is working when:
1. **Zero manual intervention** needed after adding tracks
2. **Seamless transitions** between tracks
3. **Synchronized across all users**
4. **Console shows proper event sequence**
5. **Queue updates visually** as tracks play

---

Use these test sequences to verify the auto-advance functionality is working correctly. The short duration videos allow for rapid testing without waiting for full songs to complete!