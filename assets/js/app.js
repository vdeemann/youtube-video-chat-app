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
  localPlaybackStartedAt: null, // When playback actually started on THIS client (ms)
  mediaId: null,
  mediaType: null,
  isHost: false,
  playerReady: false,
  endTriggered: false,
  ytPlayer: null,  // YouTube player instance
  isNewTrack: false, // Flag to indicate this is a freshly started track (not mid-join)
  volume: parseInt(localStorage.getItem('playerVolume') || '80', 10) // Persisted volume (0-100)
};

// ===========================================
// VOLUME CONTROL
// ===========================================
// Debounced save to localStorage (avoid writing on every pixel of slider movement)
let _volumeSaveTimeout = null;
function _debouncedSaveVolume(volume) {
  if (_volumeSaveTimeout) clearTimeout(_volumeSaveTimeout);
  _volumeSaveTimeout = setTimeout(() => {
    localStorage.setItem('playerVolume', volume.toString());
  }, 150);
}

// Throttled player volume application (avoid hammering player APIs on every input event)
let _volumeApplyTimeout = null;
let _pendingVolume = null;
function _throttledApplyVolume(volume) {
  _pendingVolume = volume;
  if (!_volumeApplyTimeout) {
    _volumeApplyTimeout = setTimeout(() => {
      applyVolumeToPlayer(_pendingVolume);
      _volumeApplyTimeout = null;
    }, 50);
  }
}

window.setPlayerVolume = function(value) {
  const volume = Math.max(0, Math.min(100, parseInt(value, 10)));
  window.playerState.volume = volume;
  
  // Lightweight UI updates (no innerHTML thrashing)
  const volumeValue = document.getElementById('volume-value');
  if (volumeValue) volumeValue.textContent = volume + '%';
  
  // Only update icon when crossing a threshold (0, 50) to avoid constant innerHTML rewrites
  const prevVolume = window.playerState._prevIconVolume || -1;
  const iconChanged = (volume === 0) !== (prevVolume === 0) || 
                      (volume > 0 && volume < 50) !== (prevVolume > 0 && prevVolume < 50) ||
                      (volume >= 50) !== (prevVolume >= 50);
  
  if (iconChanged) {
    const volumeIcon = document.getElementById('volume-icon');
    if (volumeIcon) {
      if (volume === 0) {
        volumeIcon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />`;
      } else if (volume < 50) {
        volumeIcon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />`;
      } else {
        volumeIcon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />`;
      }
    }
    window.playerState._prevIconVolume = volume;
  }
  
  // Debounce localStorage write
  _debouncedSaveVolume(volume);
  
  // Throttle player API calls
  _throttledApplyVolume(volume);
};

function applyVolumeToPlayer(volume) {
  // YouTube
  if (window.playerState.ytPlayer && typeof window.playerState.ytPlayer.setVolume === 'function') {
    try {
      window.playerState.ytPlayer.setVolume(volume);
    } catch (e) { /* player not ready */ }
  }
  
  // SoundCloud
  if (window.scWidget && typeof window.scWidget.setVolume === 'function') {
    try {
      window.scWidget.setVolume(volume);
    } catch (e) { /* widget not ready */ }
  }
  
}

// Toggle mute
window.toggleMute = function() {
  if (window.playerState.volume > 0) {
    window.playerState.previousVolume = window.playerState.volume;
    window.setPlayerVolume(0);
  } else {
    window.setPlayerVolume(window.playerState.previousVolume || 80);
  }
};

// Toggle volume popup
window.toggleVolumePopup = function() {
  const popup = document.getElementById('volume-popup');
  if (popup) {
    popup.classList.toggle('hidden');
  }
};

// Close volume popup when clicking outside
document.addEventListener('click', (e) => {
  const volumeControl = document.getElementById('volume-control');
  const popup = document.getElementById('volume-popup');
  
  if (volumeControl && popup && !volumeControl.contains(e.target)) {
    popup.classList.add('hidden');
  }
});

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
function createPlayer(media, serverStartedAt, isHost, isNewTrack) {
  if (!media) {
    console.log("[Player] No media, showing placeholder");
    showPlaceholder();
    return;
  }
  
  console.log("[Player] Creating player:", media.title, "isHost:", isHost, "isNewTrack:", isNewTrack);
  
  const container = document.getElementById('media-container');
  if (!container) return;
  
  const now = Date.now();
  let elapsed = 0;
  
  if (isNewTrack) {
    // New track starting - always begin from 0, no elapsed time calculation
    elapsed = 0;
    console.log(`[Player] New track - starting from beginning`);
  } else if (serverStartedAt) {
    // Joining mid-playback - calculate where we should be
    elapsed = Math.max(0, Math.floor((now - serverStartedAt) / 1000));
    console.log(`[Player] Joining mid-playback, seeking to: ${elapsed}s`);
  }
  
  console.log(`[Player] Server started at: ${serverStartedAt}, final start position: ${elapsed}s, isNewTrack: ${isNewTrack}`);
  
  // Destroy existing YouTube player if any
  if (window.playerState.ytPlayer) {
    try {
      window.playerState.ytPlayer.destroy();
    } catch(e) {}
    window.playerState.ytPlayer = null;
  }
  
  // Store state
  // For new tracks, use current time as the start time (ignoring server timestamp)
  // This ensures playback starts from 0 and sync is based on when THIS client started
  // IMPORTANT: Preserve the volume setting from localStorage
  const savedVolume = parseInt(localStorage.getItem('playerVolume') || '80', 10);
  window.playerState = {
    videoStartedAt: isNewTrack ? now : serverStartedAt,
    localPlaybackStartedAt: now,
    mediaId: media.media_id,
    mediaType: media.type,
    isHost: isHost,
    playerReady: false,
    endTriggered: false,
    ytPlayer: null,
    isNewTrack: isNewTrack,
    _playbackAnchored: false, // Will be set true when actual playback begins
    volume: savedVolume,
    previousVolume: window.playerState.previousVolume || savedVolume
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
      <div class="absolute inset-0 bg-gradient-to-br from-orange-900 via-red-900 to-purple-900 flex items-center justify-center" id="player-host">
        <div class="w-full h-full flex flex-col items-center justify-center px-6" style="padding-top: 70px; padding-bottom: 100px;">
          <!-- SoundCloud Player - Centered -->
          <div class="w-full flex items-center justify-center" style="max-width: 850px; max-height: 500px; height: 100%;">
            <iframe
              id="active-player"
              name="sc-player-${uniqueId}"
              src="${embedUrl}"
              frameborder="0"
              allow="autoplay; encrypted-media"
              class="w-full h-full rounded-xl shadow-2xl"
              loading="eager"
            ></iframe>
          </div>
        </div>
      </div>
    `;
    
    container.innerHTML = playerHtml;
    
    // Setup SoundCloud player - use load event instead of arbitrary delay
    const scIframe = document.getElementById('active-player');
    if (scIframe) {
      scIframe.addEventListener('load', () => {
        console.log('[SoundCloud] iframe loaded, initializing widget');
        initSoundCloud(elapsed, isHost);
      });
      // Fallback if load event doesn't fire (some browsers)
      setTimeout(() => {
        if (!window.playerState.playerReady) {
          console.log('[SoundCloud] Fallback init after timeout');
          initSoundCloud(elapsed, isHost);
        }
      }, 3000);
    }
    
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
          // Apply saved volume
          const savedVolume = window.playerState.volume;
          event.target.setVolume(savedVolume);
          console.log('[YouTube] Applied saved volume:', savedVolume);
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
          
          // State 1 = PLAYING - anchor sync timeline to actual playback start
          if (event.data === 1 && !window.playerState._playbackAnchored) {
            window.playerState._playbackAnchored = true;
            const actualPos = event.target.getCurrentTime();
            const now = Date.now();
            // Set videoStartedAt so that (now - videoStartedAt)/1000 == actualPos
            window.playerState.videoStartedAt = now - (actualPos * 1000);
            window.playerState.localPlaybackStartedAt = now;
            console.log(`[YouTube] ▶ Playback anchored: position=${actualPos.toFixed(1)}s, videoStartedAt adjusted`);
          }
          
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
        <p class="text-gray-400 text-sm">Add a YouTube or SoundCloud track to get started</p>
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
    setTimeout(() => initSoundCloud(startPosition, isHost), 200);
    return;
  }
  
  // Prevent double-initialization
  if (window.playerState.playerReady) {
    console.log("[SoundCloud] Already initialized, skipping");
    return;
  }
  
  console.log("[SoundCloud] Initializing, start position:", startPosition);
  
  const widget = window.SC.Widget(iframe);
  
  widget.bind(window.SC.Widget.Events.READY, () => {
    console.log("[SoundCloud] Ready");
    window.playerState.playerReady = true;
    
    // Apply saved volume
    const savedVolume = window.playerState.volume;
    widget.setVolume(savedVolume);
    console.log('[SoundCloud] Applied saved volume:', savedVolume);
    
    if (startPosition > 0) {
      // Mid-join: seek first, then play
      widget.seekTo(startPosition * 1000);
      widget.play();
    } else {
      // New track: just play from the start
      widget.play();
    }
  });
  
  // Anchor sync timeline when actual playback starts
  widget.bind(window.SC.Widget.Events.PLAY, () => {
    if (!window.playerState._playbackAnchored) {
      window.playerState._playbackAnchored = true;
      widget.getPosition((posMs) => {
        const actualPos = posMs / 1000;
        const now = Date.now();
        window.playerState.videoStartedAt = now - (actualPos * 1000);
        window.playerState.localPlaybackStartedAt = now;
        console.log(`[SoundCloud] ▶ Playback anchored: position=${actualPos.toFixed(1)}s, videoStartedAt adjusted`);
      });
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
  
  // Don't sync until playback has actually started and been anchored
  // This prevents the sync loop from seeking based on stale timestamps
  // before the player has loaded, buffered, and begun playing
  if (!window.playerState._playbackAnchored) return;
  
  // Additional grace period: don't sync for the first 5 seconds after anchoring
  // to let the player settle into steady playback
  const timeSinceAnchor = Date.now() - window.playerState.localPlaybackStartedAt;
  if (timeSinceAnchor < 5000) return;
  
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
  createPlayer(e.detail.media, e.detail.started_at, e.detail.is_host, e.detail.is_new_track !== false);
});

window.addEventListener("phx:set_host_status", (e) => {
  console.log("[Event] set_host_status:", e.detail.is_host);
  window.playerState.isHost = e.detail.is_host;
});

window.addEventListener("phx:show_reaction", (e) => {
  const container = document.getElementById("reactions-container");
  if (!container) return;
  
  const reaction = document.createElement("div");
  reaction.className = "absolute animate-bounce-up text-5xl";
  reaction.style.left = `${Math.random() * 100 - 50}px`; // Random position around center
  reaction.style.textShadow = "0 0 10px rgba(255,255,255,0.5)";
  reaction.textContent = e.detail.emoji;
  container.appendChild(reaction);
  setTimeout(() => reaction.remove(), 2500);
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
    // Restore scroll position if we saved one before unmount
    if (window._chatScrollPosition !== undefined) {
      this.el.scrollTop = window._chatScrollPosition;
      // Only scroll to bottom if we were at the bottom before
      if (window._chatWasAtBottom) {
        this.scrollToBottom();
      }
    } else {
      this.scrollToBottom();
    }
    this.lastMessageCount = this.getMessageCount();
    this.observer = new MutationObserver(() => {
      // Only scroll if new messages were added
      const currentCount = this.getMessageCount();
      if (currentCount > this.lastMessageCount && !this.isUserScrolled) {
        this.scrollToBottom();
      }
      this.lastMessageCount = currentCount;
    });
    this.el.addEventListener('scroll', () => {
      const isAtBottom = this.el.scrollHeight - this.el.scrollTop <= this.el.clientHeight + 50;
      this.isUserScrolled = !isAtBottom;
      // Continuously save scroll position
      window._chatScrollPosition = this.el.scrollTop;
      window._chatWasAtBottom = isAtBottom;
    });
    this.observer.observe(this.el, { childList: true, subtree: true });
  },
  beforeUpdate() {
    // Save scroll position before LiveView updates
    window._chatScrollPosition = this.el.scrollTop;
    window._chatWasAtBottom = this.el.scrollHeight - this.el.scrollTop <= this.el.clientHeight + 50;
    this.savedMessageCount = this.getMessageCount();
  },
  updated() {
    // Restore scroll position after update
    const currentCount = this.getMessageCount();
    if (currentCount === this.savedMessageCount && window._chatScrollPosition !== undefined) {
      // No new messages, restore scroll position
      this.el.scrollTop = window._chatScrollPosition;
    } else if (currentCount > this.savedMessageCount && !this.isUserScrolled) {
      // New messages, scroll to bottom
      this.scrollToBottom();
    }
    this.lastMessageCount = currentCount;
  },
  destroyed() {
    // Save scroll position when destroyed (e.g., when queue toggle causes re-render)
    window._chatScrollPosition = this.el.scrollTop;
    window._chatWasAtBottom = this.el.scrollHeight - this.el.scrollTop <= this.el.clientHeight + 50;
    if (this.observer) this.observer.disconnect();
  },
  getMessageCount() {
    const container = this.el.querySelector('#messages-container');
    return container ? container.children.length : 0;
  },
  scrollToBottom() { this.el.scrollTop = this.el.scrollHeight; }
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

const ClearOnSubmit = {
  mounted() {
    this.el.addEventListener("submit", () => {
      // Clear input after a tiny delay to let the form submit
      setTimeout(() => {
        const input = this.el.querySelector("input[type='text']");
        if (input) {
          input.value = "";
        }
      }, 10);
    });
  }
};

let Hooks = { ChatScroll, VideoEndedPusher, ClearOnSubmit };

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
});

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"});
window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());

liveSocket.connect();
window.liveSocket = liveSocket;

// Function to initialize volume UI with saved value
function initializeVolumeUI() {
  const savedVolume = parseInt(localStorage.getItem('playerVolume') || '80', 10);
  
  // Make sure playerState has the correct volume
  if (window.playerState) {
    window.playerState.volume = savedVolume;
  }
  
  const slider = document.getElementById('volume-slider');
  const volumeValue = document.getElementById('volume-value');
  const volumeIcon = document.getElementById('volume-icon');
  
  if (slider) {
    slider.value = savedVolume;
  }
  if (volumeValue) {
    volumeValue.textContent = savedVolume + '%';
  }
  if (volumeIcon) {
    if (savedVolume === 0) {
      volumeIcon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />`;
    } else if (savedVolume < 50) {
      volumeIcon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />`;
    } else {
      volumeIcon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />`;
    }
  }
  
  console.log('[Volume] Initialized UI with saved volume:', savedVolume);
}

// Initialize volume control UI on page load
document.addEventListener('DOMContentLoaded', initializeVolumeUI);

// Also initialize on LiveView navigation
window.addEventListener('phx:page-loading-stop', () => {
  setTimeout(() => {
    initializeVolumeUI();
    startVolumeObserver();
  }, 100);
});

// Watch for the volume slider to appear (for LiveView dynamic content)
// Only observe the minimal scope needed, and disconnect once found
let _volumeObserverActive = false;
function startVolumeObserver() {
  if (_volumeObserverActive) return;
  _volumeObserverActive = true;
  
  const volumeObserver = new MutationObserver((mutations) => {
    const slider = document.getElementById('volume-slider');
    if (slider) {
      const saved = localStorage.getItem('playerVolume');
      // Only reinitialize if the slider has the wrong default value
      if (saved && slider.value === '80' && saved !== '80') {
        initializeVolumeUI();
      }
      // Stop observing once we've found and initialized the slider
      volumeObserver.disconnect();
      _volumeObserverActive = false;
    }
  });
  
  volumeObserver.observe(document.body, { childList: true, subtree: true });
  
  // Safety: disconnect after 10 seconds regardless
  setTimeout(() => {
    volumeObserver.disconnect();
    _volumeObserverActive = false;
  }, 10000);
}

// Start observing when DOM is ready
document.addEventListener('DOMContentLoaded', startVolumeObserver);

console.log("✅ Simple sync player loaded (with YouTube IFrame API)");
