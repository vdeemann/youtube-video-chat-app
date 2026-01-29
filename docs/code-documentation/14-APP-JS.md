# 14-APP-JS.md - Main JavaScript Entry Point

## File: `assets/js/app.js`

This is the main JavaScript file that handles client-side media player logic, LiveView integration, and real-time synchronization.

## Overview

The JavaScript layer handles:
1. **YouTube IFrame API** - Loading and controlling YouTube videos
2. **SoundCloud Widget API** - Loading and controlling SoundCloud tracks  
3. **LiveView Integration** - Responding to server events, pushing events to server
4. **Sync Loop** - Keeping all viewers synchronized
5. **LiveView Hooks** - Chat auto-scroll, video ended events

## Imports and Setup

```javascript
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
```

| Import | Purpose |
|--------|---------|
| `phoenix_html` | Form helpers (method override for DELETE, etc.) |
| `Socket` | Phoenix WebSocket client |
| `LiveSocket` | LiveView WebSocket handler |
| `topbar` | Page loading indicator |

## Global State

```javascript
window.playerState = {
  videoStartedAt: null,  // Server timestamp when track started (ms)
  mediaId: null,         // Current media identifier
  mediaType: null,       // "youtube" or "soundcloud"
  isHost: false,         // Can control playback
  playerReady: false,    // Player initialized
  endTriggered: false,   // Prevents duplicate end events
  ytPlayer: null         // YouTube player instance
};
```

## YouTube IFrame API

### Loading the API

```javascript
function loadYouTubeAPI() {
  if (window.YT && window.YT.Player) {
    return Promise.resolve();
  }
  
  return new Promise((resolve) => {
    window.onYouTubeIframeAPIReady = () => {
      resolve();
    };
    
    const tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(tag);
  });
}
```

### Creating YouTube Player

```javascript
function initYouTubePlayer(videoId, startSeconds, isHost) {
  window.playerState.ytPlayer = new YT.Player('youtube-player-container', {
    videoId: videoId,
    playerVars: {
      autoplay: 1,
      controls: 1,
      start: startSeconds,
      enablejsapi: 1,
    },
    events: {
      onReady: (event) => {
        window.playerState.playerReady = true;
        event.target.playVideo();
      },
      onStateChange: (event) => {
        // State 0 = ended
        if (event.data === 0 && window.playerState.isHost && !window.playerState.endTriggered) {
          window.playerState.endTriggered = true;
          pushVideoEnded();
        }
        
        // State 2 = paused - auto-resume
        if (event.data === 2 && !window.playerState.endTriggered) {
          setTimeout(() => window.playerState.ytPlayer.playVideo(), 500);
        }
      }
    }
  });
}
```

**Key states**: -1=unstarted, 0=ended, 1=playing, 2=paused, 3=buffering, 5=cued

## SoundCloud Widget

```javascript
function initSoundCloud(startPosition, isHost) {
  const iframe = document.getElementById('active-player');
  const widget = window.SC.Widget(iframe);
  
  widget.bind(window.SC.Widget.Events.READY, () => {
    window.playerState.playerReady = true;
    widget.play();
    if (startPosition > 0) {
      widget.seekTo(startPosition * 1000);
    }
  });
  
  widget.bind(window.SC.Widget.Events.FINISH, () => {
    if (window.playerState.isHost && !window.playerState.endTriggered) {
      window.playerState.endTriggered = true;
      pushVideoEnded();
    }
  });
}
```

## Pushing Events to Server

```javascript
function pushVideoEnded() {
  // Method 1: Hook's pushEvent
  const hookEl = document.getElementById('room-container');
  if (hookEl && hookEl._phxHookPushEvent) {
    hookEl._phxHookPushEvent("video_ended", {});
    return;
  }
  
  // Method 2: LiveView directly
  if (window.liveSocket) {
    const view = document.querySelector('[data-phx-main]');
    const viewInstance = window.liveSocket.getViewByEl(view);
    if (viewInstance) {
      viewInstance.pushEvent("video_ended", {});
    }
  }
}
```

## Sync Loop

```javascript
setInterval(() => {
  if (!window.playerState.playerReady) return;
  
  const expectedPos = (Date.now() - window.playerState.videoStartedAt) / 1000;
  
  // YouTube sync
  if (window.playerState.ytPlayer) {
    const currentTime = window.playerState.ytPlayer.getCurrentTime();
    const drift = Math.abs(expectedPos - currentTime);
    if (drift > 5) {
      window.playerState.ytPlayer.seekTo(expectedPos, true);
    }
  }
  
  // SoundCloud sync
  if (window.scWidget) {
    window.scWidget.getPosition((pos) => {
      const drift = Math.abs(expectedPos - pos/1000);
      if (drift > 5) {
        window.scWidget.seekTo(expectedPos * 1000);
      }
    });
  }
}, 3000);
```

**Purpose**: Keeps all viewers within 5 seconds of each other.

## LiveView Event Listeners

```javascript
window.addEventListener("phx:create_player", (e) => {
  createPlayer(e.detail.media, e.detail.started_at, e.detail.is_host);
});

window.addEventListener("phx:set_host_status", (e) => {
  window.playerState.isHost = e.detail.is_host;
});

window.addEventListener("phx:show_reaction", (e) => {
  // Create animated emoji element
  const reaction = document.createElement("div");
  reaction.textContent = e.detail.emoji;
  reaction.className = "animate-bubble-up";
  document.getElementById("reactions-container").appendChild(reaction);
  setTimeout(() => reaction.remove(), 2000);
});
```

## LiveView Hooks

### ChatScroll

```javascript
const ChatScroll = {
  mounted() {
    this.scrollToBottom();
    this.observer = new MutationObserver(() => {
      if (!this.isUserScrolled) this.scrollToBottom();
    });
    this.observer.observe(this.el, { childList: true, subtree: true });
  },
  scrollToBottom() { 
    this.el.scrollTop = this.el.scrollHeight; 
  }
};
```

**Behavior**: Auto-scrolls chat, stops if user scrolls up manually.

### VideoEndedPusher

```javascript
const VideoEndedPusher = {
  mounted() {
    this.el._phxHookPushEvent = (event, payload) => {
      this.pushEvent(event, payload);
    };
  }
};
```

**Purpose**: Exposes `pushEvent` to global JavaScript code.

## LiveSocket Setup

```javascript
let Hooks = { ChatScroll, VideoEndedPusher };

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
});

liveSocket.connect();
window.liveSocket = liveSocket;
```

## Related Files

| File | Relationship |
|------|--------------|
| `show.ex` | LiveView that sends events |
| `show.html.heex` | Template with hook elements |
| `topbar.js` | Loading indicator |
