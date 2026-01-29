# 🎬 YouTube Auto-Advance Fix

## Problem Identified
YouTube videos were not triggering the `video_ended` event when they finished playing, causing them to:
- Stay in "NOW PLAYING" instead of being removed
- Not advance to the next track in queue
- Block the queue from progressing

## Root Cause
The YouTube iframe API wasn't properly detecting the end state (playerState === 0). The message listener wasn't catching all state changes from YouTube's postMessage API.

## Solution Applied

### 1. **Enhanced YouTube API Integration**
- Improved message handler to catch all YouTube postMessage events
- Added comprehensive state logging (unstarted, playing, paused, buffering, ended, cued)
- Better API initialization with retry logic
- Ensures `enablejsapi=1` is always in the iframe URL

### 2. **Fallback Progress Monitoring**
- Monitors video progress as a backup detection method
- Detects when video is stuck near the end (within 1 second)
- Triggers auto-advance if stuck for 3 seconds
- Provides redundancy if API events fail

### 3. **Better Debug Output**
```javascript
[YouTube] ⚡ State changed to: 0 (ended)
[YouTube] 🎬 VIDEO ENDED - Triggering auto-advance
[YouTube] Near end: 0.5s remaining
[YouTube] Possibly stuck at end (3)
```

## How to Apply the Fix

### Quick Method:
```batch
fix-youtube-advance.bat
```

### PowerShell (with details):
```powershell
.\fix-youtube-advance.ps1
```

### What the Fix Does:
1. Updates MediaPlayer hook with better YouTube detection
2. Rebuilds the Docker container
3. Restarts the application with fixes

## Testing YouTube Auto-Advance

### Test Sequence 1: Basic YouTube → SoundCloud
1. Add 30-second YouTube video:
   ```
   https://www.youtube.com/watch?v=aqz-KE-bpKQ
   ```
2. Add SoundCloud track:
   ```
   https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew
   ```
3. **Expected:** YouTube plays for 30 seconds, then SoundCloud starts automatically

### Test Sequence 2: Multiple YouTube Videos
1. Add three 30-second videos:
   ```
   https://www.youtube.com/watch?v=aqz-KE-bpKQ
   https://www.youtube.com/watch?v=Il-an3K9pjg
   https://www.youtube.com/watch?v=2vjPBrBU-TM
   ```
2. **Expected:** Each plays and advances without intervention

### Test Sequence 3: Mixed Queue
```
YouTube (30s) → SoundCloud → YouTube (1m) → SoundCloud
```
**Expected:** Seamless transitions between platforms

## Console Monitoring

### Open Browser Console (F12)

#### During Playback:
```
[YouTube] === INITIALIZING PLAYER ===
[YouTube] Setup attempt 1/10
[YouTube] API commands sent
[YouTube] Message handler attached
[YouTube] ⚡ State changed to: 1 (playing)
[YouTube] ▶️ Video PLAYING
[YouTube] Duration: 30 seconds
```

#### When Video Ends:
```
[YouTube] ⚡ State changed to: 0 (ended)
[YouTube] 🎬 VIDEO ENDED - Triggering auto-advance
=== VIDEO_ENDED EVENT ===
Current media: "YouTube Video"
Is host: true
Host triggering auto-advance to next track
=== PLAY NEXT CALLED ===
Playing next track: The Code East London Sa by Thecxde
```

#### Fallback Detection (if API fails):
```
[YouTube] Near end: 0.8s remaining
[YouTube] Possibly stuck at end (1)
[YouTube] Possibly stuck at end (2)
[YouTube] Possibly stuck at end (3)
[YouTube] 🎬 FALLBACK: Video appears ended (stuck at end)
```

## Verification Checklist

### ✅ Working Correctly When:
- [ ] YouTube videos advance to next track automatically
- [ ] "NOW PLAYING" updates when video ends
- [ ] Queue count decreases
- [ ] Console shows "VIDEO ENDED" message
- [ ] Next track (YouTube or SoundCloud) starts within 2 seconds
- [ ] All users see the same advancement

### ❌ Not Working If:
- [ ] Video ends but stays in "NOW PLAYING"
- [ ] Queue doesn't update
- [ ] No console messages about ending
- [ ] Need to manually skip
- [ ] Next track doesn't start

## Important Notes

### Host Requirement
- **Only the HOST can trigger auto-advance**
- Look for the purple "Skip" button to confirm you're host
- Non-hosts will see the change but won't trigger it

### Browser Compatibility
- **Chrome/Edge:** Best support
- **Firefox:** May need autoplay permission
- **Safari:** Check autoplay settings

### Autoplay Policy
Some browsers block autoplay. If the next video doesn't start:
1. Click anywhere on the page
2. Try manual play once
3. Subsequent videos should auto-play

## Technical Details

### YouTube Player States
```javascript
-1 = unstarted
 0 = ended      // ← This triggers auto-advance
 1 = playing
 2 = paused
 3 = buffering
 5 = video cued
```

### Event Flow
```
YouTube Video Playing
    ↓
Player State → 0 (ended)
    ↓
MessageHandler receives event
    ↓
Triggers "video_ended" event
    ↓
LiveView handles event (if host)
    ↓
RoomServer.play_next() called
    ↓
Next track starts
```

### Fallback Mechanism
If YouTube API fails to report ended state:
1. Progress monitor checks every second
2. Detects if stuck near end (< 1 second remaining)
3. If stuck for 3 checks, assumes ended
4. Triggers auto-advance

## Debug Commands

### Check YouTube API Status:
```javascript
// In browser console while YouTube is playing
const iframe = document.getElementById('youtube-iframe');
console.log("YouTube iframe:", iframe?.src);
console.log("Has enablejsapi:", iframe?.src.includes('enablejsapi=1'));
```

### Force End Event (Testing Only):
```javascript
// Simulate video ending (HOST ONLY)
const hook = document.querySelector('[phx-hook="MediaPlayer"]').__phoenix_hook__;
if (hook) {
  hook.pushEvent("video_ended", { type: "youtube" });
}
```

### Monitor All YouTube Messages:
```javascript
// See all postMessage communication
window.addEventListener('message', (e) => {
  if (e.origin.includes('youtube')) {
    console.log('YouTube message:', e.data);
  }
});
```

## Summary

The YouTube auto-advance issue has been fixed by:
1. **Improving YouTube API event detection**
2. **Adding fallback progress monitoring**
3. **Ensuring proper API initialization**
4. **Better error handling and logging**

YouTube videos should now properly detect when they end and automatically advance to the next track in the queue, just like SoundCloud tracks do.

Run `fix-youtube-advance.bat` to apply the fix!