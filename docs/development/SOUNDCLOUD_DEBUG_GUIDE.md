# SoundCloud Debugging Guide

## How to Debug SoundCloud Playback Issues

### 1. Open Browser Developer Console
- Press **F12** in your browser
- Go to the **Console** tab
- Look for messages starting with `[SoundCloud]`

### 2. Expected Console Output (Success)
When SoundCloud works properly, you should see:
```
[MediaPlayer] Mounted - Type: soundcloud, Host: true, ID: soundcloud-iframe
[SoundCloud] Starting initialization
[SoundCloud] API already loaded, setting up widget
[SoundCloud] Creating widget for iframe: soundcloud-iframe
[SoundCloud] Widget created, binding events
[SoundCloud] Widget READY!
[SoundCloud] Track loaded: {title: "Track Name", ...}
[SoundCloud] Volume: 80
[SoundCloud] Host mode - attempting autoplay
[SoundCloud] Attempting to start playback...
[SoundCloud] Is paused: true
[SoundCloud] Calling play()
[SoundCloud] ▶️ PLAYING
```

### 3. Common Issues and Solutions

#### Issue: "Widget API not available"
**Console shows:**
```
[SoundCloud] Widget API not available
```
**Solution:** 
- The SoundCloud API script hasn't loaded
- Wait a few seconds, it will retry automatically
- Check network tab for blocked requests

#### Issue: Track Won't Play
**Console shows:**
```
[SoundCloud] Is paused: true
[SoundCloud] Still paused after play(): true
[SoundCloud] Showing manual play button
```
**Solution:**
- Click the orange manual play button (host only)
- Try clicking directly on the SoundCloud player
- Check if the track allows embedding

#### Issue: "This track is not streamable"
**Solution:**
- The track owner has disabled external playback
- Try a different SoundCloud URL
- Use tracks that explicitly allow embedding

#### Issue: No Sound but Shows Playing
**Console shows:**
```
[SoundCloud] ▶️ PLAYING
[SoundCloud] Volume: 0
```
**Solution:**
- Check system volume
- Check browser tab isn't muted
- The fix now sets volume to 80% automatically

### 4. Manual Testing Steps

1. **Test a Known Working Track:**
   Try this public SoundCloud URL:
   ```
   https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew
   ```

2. **Check Widget State:**
   In browser console, run:
   ```javascript
   // Get the widget
   const iframe = document.getElementById('soundcloud-iframe');
   const widget = SC.Widget(iframe);
   
   // Check if paused
   widget.isPaused(paused => console.log('Paused:', paused));
   
   // Get position
   widget.getPosition(pos => console.log('Position:', pos));
   
   // Try to play
   widget.play();
   ```

3. **Force Play Manually:**
   In console:
   ```javascript
   SC.Widget(document.getElementById('soundcloud-iframe')).play();
   ```

### 5. Network Debugging

Check Network tab (F12 → Network) for:
- `api.js` from `w.soundcloud.com` (should be 200 OK)
- `player` requests to SoundCloud (should be 200 OK)
- Any blocked or failed requests (shown in red)

### 6. Browser-Specific Issues

#### Chrome
- Check chrome://settings/content/sound
- Ensure site isn't blocked from playing sound
- Try incognito mode to rule out extensions

#### Firefox
- Check about:preferences#privacy
- Look for "Autoplay" settings
- Set to "Allow Audio and Video"

#### Edge
- Similar to Chrome settings
- Check edge://settings/content/mediaAutoplay

### 7. Advanced Debugging

#### Check All Widget Events:
```javascript
const widget = SC.Widget(document.getElementById('soundcloud-iframe'));
const events = SC.Widget.Events;

Object.keys(events).forEach(event => {
  widget.bind(events[event], (e) => {
    console.log(`Event: ${event}`, e);
  });
});
```

#### Get Full Widget State:
```javascript
const widget = SC.Widget(document.getElementById('soundcloud-iframe'));

widget.getCurrentSound(sound => console.log('Sound:', sound));
widget.getVolume(vol => console.log('Volume:', vol));
widget.isPaused(paused => console.log('Paused:', paused));
widget.getPosition(pos => console.log('Position:', pos));
widget.getDuration(dur => console.log('Duration:', dur));
```

### 8. If Nothing Works

1. **Clear Everything and Rebuild:**
   ```powershell
   docker-compose down -v
   docker system prune -a
   docker-compose up --build
   ```

2. **Try Different Track:**
   Some tracks have embedding restrictions

3. **Check Logs:**
   ```powershell
   docker-compose logs web
   ```

4. **Test Outside Docker:**
   Create a simple HTML file to test SoundCloud embed:
   ```html
   <!DOCTYPE html>
   <html>
   <head>
     <script src="https://w.soundcloud.com/player/api.js"></script>
   </head>
   <body>
     <iframe id="sc-widget" 
             src="https://w.soundcloud.com/player/?url=https://soundcloud.com/artist/track&auto_play=true"
             width="100%" height="166">
     </iframe>
     <script>
       const widget = SC.Widget('sc-widget');
       widget.bind(SC.Widget.Events.READY, () => {
         console.log('Ready!');
         widget.play();
       });
     </script>
   </body>
   </html>
   ```

### 9. Report Format

If you need to report an issue, include:
1. Browser and version
2. Console output (all [SoundCloud] messages)
3. Network tab screenshot
4. The SoundCloud URL you're trying to play
5. Whether you're the host or viewer

### 10. Quick Fixes to Try

1. **Refresh the page** (F5)
2. **Hard refresh** (Ctrl+F5)
3. **Try incognito/private mode**
4. **Disable ad blockers**
5. **Try a different browser**
6. **Click the manual play button** (orange button, host only)
7. **Click directly on the SoundCloud player**
8. **Wait 5-10 seconds** (auto-retry happens)