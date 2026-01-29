# YouTube Auto-Play Fix

## Problem
When a YouTube track is added to the queue, it does not automatically start playing. Users have to manually click the play button on the YouTube player.

## Root Cause
The YouTube embed URLs were being generated with the parameter `autoplay=0`, which explicitly disables automatic playback.

## Solution
Changed all YouTube embed URL generation to use `autoplay=1` instead of `autoplay=0`.

### Files Modified

1. **`lib/youtube_video_chat_app_web/live/room_live/show.ex`**
   - Updated `parse_media_url` function to generate YouTube embed URLs with `autoplay=1`
   - Added `mute=0` parameter to indicate we want sound (though browsers may override this)

2. **`assets/js/app.js`**
   - Updated iframe reload handler to ensure `autoplay=1` is set when updating iframe src
   - Modified legacy video_id handler to use `autoplay=1`

3. **`assets/js/hooks/media_player.js`**
   - Updated `reloadMedia` function to ensure `autoplay=1` is added if missing

4. **`lib/youtube_video_chat_app/rooms/room_server.ex`**
   - Fixed legacy video conversion to use `autoplay=1`

## Browser Autoplay Policies

Modern browsers have strict autoplay policies to prevent unwanted audio/video playback:

### Chrome/Edge (Chromium-based)
- **Autoplay with sound is allowed if:**
  - User has interacted with the domain (click, tap, key press)
  - User has frequently played media on the site
  - Site has been added to home screen (mobile)
  - MEI (Media Engagement Index) score is high enough

### Firefox
- **Autoplay with sound is allowed if:**
  - User has interacted with the page
  - Site has been granted autoplay permission
  - Video is muted

### Safari
- **Most restrictive:**
  - Generally requires user interaction for any autoplay
  - Can be configured in preferences per site

## Workarounds for Autoplay Restrictions

### Option 1: Muted Autoplay (Most Reliable)
```javascript
// Change embed URL to include mute=1
embed_url = "...&autoplay=1&mute=1"
```
- **Pros:** Works in all browsers without user interaction
- **Cons:** No sound initially, user must unmute manually

### Option 2: Click-to-Start
Add a "Click to Start" overlay that triggers playback on first interaction:
```javascript
document.addEventListener('click', function() {
  // Trigger play on first click
  iframe.contentWindow.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
}, { once: true });
```

### Option 3: Progressive Enhancement
1. Try autoplay with sound
2. If blocked, fallback to muted autoplay
3. Show unmute button prominently

## Testing the Fix

1. **Start the server:**
   ```bash
   mix phx.server
   ```

2. **Create or join a room**

3. **Add a YouTube video** - paste a YouTube URL in the playlist input

4. **Expected behavior:**
   - If this is your first visit or no prior interaction: Video may not autoplay
   - After clicking anywhere on the page: Videos should autoplay
   - For returning users with high MEI: Videos should autoplay immediately

## Troubleshooting

### Videos still not auto-playing?

1. **Check browser console** for autoplay policy violations:
   ```
   DOMException: play() failed because the user didn't interact with the document first
   ```

2. **Browser Settings:**
   - Chrome: `chrome://settings/content/sound`
   - Firefox: `about:preferences#privacy` → Autoplay
   - Safari: Preferences → Websites → Auto-Play

3. **Test with muted autoplay:**
   - Temporarily change `mute=0` to `mute=1` in the code
   - If this works, the issue is browser autoplay policy

4. **Ensure HTTPS:**
   - Some browsers have stricter policies on HTTP
   - Use HTTPS in production for best compatibility

## Future Improvements

1. **Detect autoplay failure** and show a play button:
   ```javascript
   iframe.contentWindow.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
   // Listen for state changes to detect if play was blocked
   ```

2. **User preference system:**
   - Remember user's autoplay preference
   - Allow toggling between auto/manual play

3. **Smart muting:**
   - Start muted if no prior interaction
   - Automatically unmute after first user interaction

## References
- [Chrome Autoplay Policy](https://developer.chrome.com/blog/autoplay/)
- [Firefox Autoplay Blocking](https://support.mozilla.org/en-US/kb/block-autoplay)
- [YouTube IFrame API](https://developers.google.com/youtube/iframe_api_reference)
