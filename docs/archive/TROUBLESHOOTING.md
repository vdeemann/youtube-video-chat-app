# Queue System Troubleshooting Guide

## Issue: Videos Not Auto-Advancing

### What to Check

1. **Browser Console (F12)**
   - Look for `[MediaPlayer] 🎬 MOUNTED` message
   - Look for `[YouTube] ⚠️ STARTING PROGRESS CHECKING - IS HOST`
   - Look for progress updates: `[YouTube] ⏱️ Check #X`
   - Look for `[YouTube] ✅ VIDEO ENDED`

2. **Server Logs** (`docker-compose logs -f web`)
   - Look for `=== PLAY_NEXT CALLED ===`
   - Look for `✅ ADVANCING TO NEXT TRACK`

### Common Issues

#### Issue 1: Hook Not Attaching
**Symptom**: No `[MediaPlayer] MOUNTED` in browser console

**Solutions**:
1. Rebuild Docker container:
   ```bash
   docker-compose down
   docker-compose build
   docker-compose up
   ```

2. Hard refresh browser (Ctrl+Shift+R or Cmd+Shift+R)

3. Check if iframe has `phx-hook="MediaPlayer"` attribute:
   - Open browser DevTools
   - Inspect the iframe
   - Look for `phx-hook="MediaPlayer"` in the HTML

#### Issue 2: Not Detecting as Host
**Symptom**: Console shows `Is Host: false`

**Solutions**:
- You need to be the first person in the room
- Check server logs for `host_id` value
- Close all tabs and rejoin the room

#### Issue 3: Progress Not Being Tracked
**Symptom**: No progress check messages in console

**Solutions**:
1. Ensure you see: `[YouTube] ⚠️ STARTING PROGRESS CHECKING - IS HOST`
2. Check if YouTube iframe API is loading:
   - Look for YouTube API messages in console
   - Ensure iframe has `enablejsapi=1` in URL

3. Try a different video (some videos have playback restrictions)

#### Issue 4: Video Ends But Doesn't Advance
**Symptom**: Progress reaches 100% but no advancement

**Solutions**:
1. Check if `video_ended` event is being sent:
   - Look for `[YouTube] 🎬🎬🎬 VIDEO ENDED` in console
   - Look for `📤 Sending video_ended event` in console

2. Check if server receives it:
   - Look for `🎬 VIDEO_ENDED EVENT` in server logs
   - Look for `🚀 HOST DETECTED - Triggering auto-advance`

3. Ensure WebSocket is connected:
   - Look for LiveView connection in console
   - Try refreshing the page

### Debug Mode

Add this to your browser console to enable extra debug logging:

```javascript
// Enable all MediaPlayer logging
window.addEventListener('message', (event) => {
  if (event.origin.includes('youtube')) {
    console.log('[YouTube API]', event.data);
  }
});
```

### Testing Checklist

Test with short videos to diagnose quickly:

1. **30-second video**: https://www.youtube.com/watch?v=jNQXAC9IVRw
2. **10-second video**: https://www.youtube.com/watch?v=aqz-KE-bpKQ

Expected behavior:
- [ ] First video starts immediately
- [ ] Browser console shows progress checks
- [ ] At ~98%, console shows "VIDEO ENDED"
- [ ] Server logs show "PLAY_NEXT CALLED"
- [ ] Second video starts automatically
- [ ] Queue updates (second video removed)

### Quick Fixes

#### Reset Everything
```bash
# Stop containers
docker-compose down

# Remove volumes (clears database)
docker-compose down -v

# Rebuild and start
docker-compose build
docker-compose up
```

#### Clear Browser State
1. Hard refresh: `Ctrl+Shift+R` (Windows) or `Cmd+Shift+R` (Mac)
2. Clear cache and cookies for localhost
3. Try incognito/private window

#### Verify Files Are Updated

Check if your changes are in the container:
```bash
# View the media_player.js in container
docker-compose exec web cat /app/assets/js/hooks/media_player.js | head -30
```

Look for the new emoji logging (🎬, 👑, etc.)

### Still Not Working?

1. **Check the iframe src URL**:
   - Open DevTools → Elements
   - Find the YouTube iframe
   - Check if `enablejsapi=1` and `autoplay=1` are in the URL

2. **Test without Docker**:
   ```bash
   mix deps.get
   cd assets && npm install
   mix phx.server
   ```
   
3. **Check for CORS issues**:
   - Open Network tab in DevTools
   - Look for failed requests to YouTube

### Getting Help

When reporting issues, include:

1. **Browser console logs** (full output)
2. **Server logs** (docker-compose logs -f web)
3. **Steps to reproduce**
4. **Which browser and version**
5. **Are you the host?**
6. **Screenshot of queue UI**

### Success Indicators

When it's working, you'll see:

**Browser Console:**
```
============================================================
[MediaPlayer] 🎬 MOUNTED
============================================================
[MediaPlayer] 🎥 Type: youtube
[MediaPlayer] 👑 Is Host: true
[YouTube] ⚠️ STARTING PROGRESS CHECKING - IS HOST
[YouTube] ⏱️ Check #4: 5.23/180.00s (2.9%)
[YouTube] ⏱️ Check #8: 10.45/180.00s (5.8%)
...
[YouTube] ⏱️ Check #352: 176.50/180.00s (98.1%)
[YouTube] 🎬🎬🎬 VIDEO ENDED - ADVANCING TO NEXT
[MediaPlayer] 🔄 Reload event - Next media: {...}
```

**Server Logs:**
```
=== PLAY_NEXT CALLED ===
🎵 Current: First Video
📁 Queue: 1 items
✅ ADVANCING TO NEXT TRACK
🎬 Now Playing: Second Video
📁 Remaining in queue: 0
```

