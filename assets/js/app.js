// Simple synchronized playback system
// Server is source of truth - each client plays independently

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// ===========================================
// GLOBAL STATE
// ===========================================
window.playerState = {
  videoStartedAt: null,  // Server timestamp when track started (ms)
  mediaId: null,
  mediaType: null,
  isHost: false,
  playerReady: false,
  endTriggered: false,
  ytPlayer: null  // YouTube player instance
};

// ===========================================
// LOAD YOUTUBE IFRAME API
// ===========================================
function loadYouTubeAPI() {
  if (window.YT && window.YT.Player) {
    console.log("[YouTube] API already loaded");
    return Promise.resolve();
  }
  
  return new Promise((resolve) => {
    if (document.querySelector('script[src*="youtube.com/iframe_api"]')) {
      // Script already added, wait for it
      const checkYT = setInterval(() => {
        if (window.YT && window.YT.Player) {
          clearInterval(checkYT);
          resolve();
        }
      }, 100);
      return;
    }
    
    window.onYouTubeIframeAPIReady = () => {
      console.log("[YouTube] API loaded and ready");
      resolve();
    };
    
    const tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    const firstScript = document.getElementsByTagName('script')[0];
    firstScript.parentNode.insertBefore(tag, firstScript);
  });
}

// Load YouTube API immediately
loadYouTubeAPI();

// ===========================================
// CREATE PLAYER
// Called when: 1) joining room with active track, 2) new track starts
// ===========================================
function createPlayer(media, serverStartedAt, isHost) {
  if (!media) {
    console.log("[Player] No media, showing placeholder");
    showPlaceholder();
    return;
  }
  
  console.log("[Player] Creating player:", media.title, "isHost:", isHost);
  
  const container = document.getElementById('media-container');
  if (!container) return;
  
  // Calculate current position based on server start time
  const now = Date.now();
  const elapsed = serverStartedAt ? Math.floor((now - serverStartedAt) / 1000) : 0;
  console.log(`[Player] Server started at: ${serverStartedAt}, elapsed: ${elapsed}s`);
  
  // Destroy existing YouTube player if any
  if (window.playerState.ytPlayer) {
    try {
      window.playerState.ytPlayer.destroy();
    } catch(e) {}
    window.playerState.ytPlayer = null;
  }
  
  // Store state
  window.playerState = {
    videoStartedAt: serverStartedAt || now,
    mediaId: media.media_id,
    mediaType: media.type,
    isHost: isHost,
    playerReady: false,
    endTriggered: false,
    ytPlayer: null
  };
  
  // Build player HTML
  let playerHtml;
  
  if (media.type === "youtube") {
    // For YouTube, we create a div that the API will replace with an iframe
    playerHtml = `
      <div class="absolute inset-0 bg-black" id="player-host">
        <div class="absolute left-0 right-0" style="top: 76px; bottom: 100px;">
          <div class="w-full h-full flex items-center justify-center">
            <div class="w-full h-full" style="max-width: calc((100vh - 176px) * 1.78);">
              <div id="youtube-player-container" class="w-full h-full"></div>
            </div>
          </div>
        </div>
      </div>
    `;
    
    container.innerHTML = playerHtml;
    
    // Initialize YouTube player with the API
    initYouTubePlayer(media.media_id, elapsed, isHost);
    
  } else if (media.type === "soundcloud") {
    // Add unique identifier to make each iframe distinct per tab
    const uniqueId = `${now}_${Math.random().toString(36).substr(2, 9)}`;
    let embedUrl = media.embed_url + `&_t=${uniqueId}`;
    
    playerHtml = `
      <div class="relative w-full h-full bg-gradient-to-br from-orange-900 via-red-900 to-purple-900" id="player-host">
        <div class="absolute inset-0 flex items-center justify-center">
          <div class="w-full max-w-4xl px-8">
            <div class="text-center mb-4">
              <h2 class="text-white text-2xl font-bold mb-2">${media.title || 'SoundCloud Track'}</h2>
              <p class="text-white/70 text-sm">SoundCloud Track</p>
            </div>
            <div class="relative h-96">
              <iframe
                id="active-player"
                name="sc-player-${uniqueId}"
                src="${embedUrl}"
                frameborder="0"
                allow="autoplay; encrypted-media"
                class="w-full h-full rounded-lg shadow-2xl"
                loading="eager"
              ></iframe>
            </div>
            <div class="text-center mt-4">
              <p class="text-white/60 text-sm">Synced playback • All users hear the same position</p>
            </div>
          </div>
        </div>
      </div>
    `;
    
    container.innerHTML = playerHtml;
    
    // Setup SoundCloud player after it loads
    setTimeout(() => initSoundCloud(elapsed, isHost), 1000);
  }
}

// ===========================================
// YOUTUBE PLAYER INITIALIZATION (Official API)
// ===========================================
function initYouTubePlayer(videoId, startSeconds, isHost) {
  console.log("[YouTube] Initializing player for video:", videoId, "start:", startSeconds, "isHost:", isHost);
  
  // Make sure API is loaded
  if (!window.YT || !window.YT.Player) {
    console.log("[YouTube] API not ready, waiting...");
    loadYouTubeAPI().then(() => {
      initYouTubePlayer(videoId, startSeconds, isHost);
    });
    return;
  }
  
  const containerEl = document.getElementById('youtube-player-container');
  if (!containerEl) {
    console.error("[YouTube] Container not found");
    return;
  }
  
  // Get container dimensions
  const width = containerEl.clientWidth || 800;
  const height = containerEl.clientHeight || 450;
  
  try {
    window.playerState.ytPlayer = new YT.Player('youtube-player-container', {
      width: width,
      height: height,
      videoId: videoId,
      playerVars: {
        autoplay: 1,
        controls: 1,
        rel: 0,
        modestbranding: 1,
        playsinline: 1,
        start: startSeconds,
        enablejsapi: 1,
        origin: window.location.origin
      },
      events: {
        onReady: (event) => {
          console.log("[YouTube] Player ready");
          window.playerState.playerReady = true;
          event.target.playVideo();
        },
        onStateChange: (event) => {
          const stateNames = {
            '-1': 'unstarted',
            '0': 'ended',
            '1': 'playing',
            '2': 'paused',
            '3': 'buffering',
            '5': 'cued'
          };
          console.log("[YouTube] State changed to:", event.data, `(${stateNames[event.data] || 'unknown'})`);
          
          // State 0 = ENDED
          if (event.data === 0) {
            console.log("[YouTube] VIDEO ENDED! isHost:", window.playerState.isHost, "endTriggered:", window.playerState.endTriggered);
            if (window.playerState.isHost && !window.playerState.endTriggered) {
              console.log("[YouTube] 🚀 Host triggering queue advance!");
              window.playerState.endTriggered = true;
              pushVideoEnded();
            }
          }
          
          // State 2 = PAUSED - auto-resume if not ended
          if (event.data === 2 && !window.playerState.endTriggered) {
            console.log("[YouTube] Paused - auto-resuming");
            setTimeout(() => {
              if (window.playerState.ytPlayer && !window.playerState.endTriggered) {
                window.playerState.ytPlayer.playVideo();
              }
            }, 500);
          }
        },
        onError: (event) => {
          console.error("[YouTube] Player error:", event.data);
        }
      }
    });
    
    console.log("[YouTube] Player created successfully");
  } catch(e) {
    console.error("[YouTube] Error creating player:", e);
  }
}

function showPlaceholder() {
  const container = document.getElementById('media-container');
  if (!container) return;
  
  // Destroy existing YouTube player if any
  if (window.playerState.ytPlayer) {
    try {
      window.playerState.ytPlayer.destroy();
    } catch(e) {}
    window.playerState.ytPlayer = null;
  }
  
  container.innerHTML = `
    <div class="flex items-center justify-center w-full h-full bg-gray-900" id="no-media-placeholder">
      <div class="text-center">
        <svg class="w-24 h-24 mx-auto mb-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-white text-xl mb-2">No media playing</p>
        <p class="text-gray-400 text-sm">Add a YouTube video or SoundCloud track to get started</p>
      </div>
    </div>
  `;
  
  window.playerState.videoStartedAt = null;
  window.playerState.mediaId = null;
}

// ===========================================
// SOUNDCLOUD INITIALIZATION
// ===========================================
function initSoundCloud(startPosition, isHost) {
  const iframe = document.getElementById('active-player');
  if (!iframe) return;
  
  if (!window.SC?.Widget) {
    console.log("[SoundCloud] API not loaded, retrying...");
    setTimeout(() => initSoundCloud(startPosition, isHost), 500);
    return;
  }
  
  console.log("[SoundCloud] Initializing, start position:", startPosition);
  
  const widget = window.SC.Widget(iframe);
  
  widget.bind(window.SC.Widget.Events.READY, () => {
    console.log("[SoundCloud] Ready");
    window.playerState.playerReady = true;
    
    widget.play();
    
    if (startPosition > 0) {
      setTimeout(() => {
        widget.seekTo(startPosition * 1000);
        widget.play();
      }, 500);
    }
  });
  
  widget.bind(window.SC.Widget.Events.FINISH, () => {
    console.log("[SoundCloud] FINISH event fired, isHost:", window.playerState.isHost);
    if (window.playerState.isHost && !window.playerState.endTriggered) {
      console.log("[SoundCloud] Finished - advancing queue");
      window.playerState.endTriggered = true;
      pushVideoEnded();
    }
  });
  
  // Also track progress to catch near-end
  widget.bind(window.SC.Widget.Events.PLAY_PROGRESS, (data) => {
    if (data.relativePosition > 0.99 && window.playerState.isHost && !window.playerState.endTriggered) {
      console.log("[SoundCloud] 99% complete - triggering end");
      window.playerState.endTriggered = true;
      pushVideoEnded();
    }
  });
  
  // Store widget reference for sync
  window.scWidget = widget;
}

// ===========================================
// PUSH VIDEO ENDED TO SERVER
// ===========================================
function pushVideoEnded() {
  console.log("[Player] 🔔 Pushing video_ended event to server");
  
  // Method 1: Try using the hook's pushEvent
  const hookEl = document.getElementById('room-container');
  if (hookEl && hookEl._phxHookPushEvent) {
    console.log("[Player] Using hook pushEvent method");
    hookEl._phxHookPushEvent("video_ended", {});
    return;
  }
  
  // Method 2: Find the LiveView and push directly
  if (window.liveSocket) {
    const view = document.querySelector('[data-phx-main]');
    if (view) {
      const viewInstance = window.liveSocket.getViewByEl(view);
      if (viewInstance) {
        console.log("[Player] Using LiveView pushEvent method");
        viewInstance.pushEvent("video_ended", {}, () => {
          console.log("[Player] video_ended event pushed successfully");
        });
        return;
      }
    }
  }
  
  console.error("[Player] ❌ Could not push video_ended event - no method available");
}

// ===========================================
// SYNC LOOP - Keep players in sync with server timeline
// ===========================================
setInterval(() => {
  if (!window.playerState.videoStartedAt || !window.playerState.playerReady) return;
  if (window.playerState.endTriggered) return; // Don't sync after video ended
  
  const expectedPos = (Date.now() - window.playerState.videoStartedAt) / 1000;
  
  // YouTube sync using official API
  if (window.playerState.mediaType === "youtube" && window.playerState.ytPlayer) {
    try {
      const currentTime = window.playerState.ytPlayer.getCurrentTime();
      const drift = Math.abs(expectedPos - currentTime);
      
      if (drift > 5) {
        console.log(`[Sync] YouTube drift ${drift.toFixed(1)}s - resyncing`);
        window.playerState.ytPlayer.seekTo(expectedPos, true);
      }
    } catch(e) {
      // Player might not be ready yet
    }
  }
  
  // SoundCloud sync
  if (window.playerState.mediaType === "soundcloud" && window.scWidget) {
    window.scWidget.isPaused((paused) => {
      if (paused && !window.playerState.endTriggered) {
        console.log("[Sync] SoundCloud paused - resuming");
        window.scWidget.play();
        setTimeout(() => {
          const newExpected = (Date.now() - window.playerState.videoStartedAt) / 1000;
          window.scWidget.seekTo(newExpected * 1000);
        }, 300);
      }
    });
    
    window.scWidget.getPosition((pos) => {
      const current = pos / 1000;
      const drift = Math.abs(expectedPos - current);
      if (drift > 5) {
        console.log(`[Sync] SoundCloud drift ${drift.toFixed(1)}s - resyncing`);
        window.scWidget.seekTo(expectedPos * 1000);
      }
    });
  }
}, 3000);

// ===========================================
// LIVEVIEW EVENT HANDLERS
// ===========================================
window.addEventListener("phx:create_player", (e) => {
  console.log("[Event] create_player received:", e.detail);
  createPlayer(e.detail.media, e.detail.started_at, e.detail.is_host);
});

window.addEventListener("phx:set_host_status", (e) => {
  console.log("[Event] set_host_status:", e.detail.is_host);
  window.playerState.isHost = e.detail.is_host;
});

window.addEventListener("phx:show_reaction", (e) => {
  const container = document.getElementById("reactions-container");
  if (!container) return;
  const reaction = document.createElement("div");
  reaction.className = "absolute bottom-0 animate-bubble-up text-3xl";
  reaction.style.left = `${Math.random() * 60}px`;
  reaction.textContent = e.detail.emoji;
  container.appendChild(reaction);
  setTimeout(() => reaction.remove(), 2000);
});

// ===========================================
// LOAD SOUNDCLOUD API
// ===========================================
(function() {
  if (window.SC?.Widget) return;
  const script = document.createElement('script');
  script.src = 'https://w.soundcloud.com/player/api.js';
  document.head.appendChild(script);
})();

// ===========================================
// LIVEVIEW HOOKS
// ===========================================
const ChatScroll = {
  mounted() {
    this.scrollToBottom();
    this.observer = new MutationObserver(() => {
      if (!this.isUserScrolled) this.scrollToBottom();
    });
    this.el.addEventListener('scroll', () => {
      const isAtBottom = this.el.scrollHeight - this.el.scrollTop <= this.el.clientHeight + 50;
      this.isUserScrolled = !isAtBottom;
    });
    this.observer.observe(this.el, { childList: true, subtree: true });
  },
  scrollToBottom() { this.el.scrollTop = this.el.scrollHeight; },
  destroyed() { if (this.observer) this.observer.disconnect(); }
};

const VideoEndedPusher = {
  mounted() {
    // Store reference to this hook's pushEvent on the element
    this.el._phxHookPushEvent = (event, payload) => {
      console.log("[Hook] Pushing event via hook:", event);
      this.pushEvent(event, payload);
    };
    console.log("[Hook] VideoEndedPusher mounted and ready");
  }
};

let Hooks = { ChatScroll, VideoEndedPusher };

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
});

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"});
window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());

liveSocket.connect();
window.liveSocket = liveSocket;

console.log("✅ Simple sync player loaded (with YouTube IFrame API)");
