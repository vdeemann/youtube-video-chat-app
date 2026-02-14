// ==========================================================================
// Simplified synchronized playback system
//
// The server sends ONE event type: "sync_player" containing:
//   { media, started_at, server_now, is_host }
//
// The client computes seek position as:
//   position = (Date.now() - started_at) / 1000
//
// That's it.  No dedup, no dual paths, no data-attribute fallback.
// ==========================================================================

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// ===========================================
// GLOBAL STATE
// ===========================================
window.playerState = {
  startedAt: null,        // ms epoch — when track position 0 started
  mediaId: null,
  mediaType: null,
  isHost: false,
  playerReady: false,
  endTriggered: false,
  ytPlayer: null,
  volume: parseInt(localStorage.getItem('playerVolume') || '80', 10)
};

// ===========================================
// USER INTERACTION TRACKING (autoplay policy)
// ===========================================
// Browsers block unmuted autoplay until the user interacts with the page.
// We track this so we can start muted on fresh loads and show an overlay.
window._userHasInteracted = false;

function markUserInteracted() {
  if (window._userHasInteracted) return;
  window._userHasInteracted = true;
  hideUnmuteOverlay();

  // Unmute the current player now that we have a user gesture
  try {
    const yt = window.playerState.ytPlayer;
    if (yt && typeof yt.unMute === 'function') {
      yt.setVolume(window.playerState.volume);
      yt.unMute();
      // Force the audio stream to re-engage by nudging playback
      const cur = yt.getCurrentTime?.();
      if (cur != null && cur > 0) yt.seekTo(cur, true);
      yt.playVideo();
    }
  } catch (_) {}
  try {
    if (window.scWidget) {
      window.scWidget.setVolume(window.playerState.volume);
      // Nudge SoundCloud to re-engage audio by pausing and immediately playing
      window.scWidget.play();
    }
  } catch (_) {}
}

// Any user interaction on the page counts
['click', 'keydown', 'touchstart'].forEach(evt => {
  document.addEventListener(evt, markUserInteracted, { once: false, capture: true });
});

// ===========================================
// UNMUTE OVERLAY
// ===========================================
function showUnmuteOverlay() {
  if (document.getElementById('unmute-overlay')) return;
  const overlay = document.createElement('div');
  overlay.id = 'unmute-overlay';
  overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;z-index:90;display:flex;align-items:center;justify-content:center;pointer-events:none;';
  overlay.innerHTML = `
    <button id="unmute-btn" style="
      pointer-events:auto;
      display:flex;align-items:center;gap:10px;
      padding:14px 28px;
      background:rgba(0,0,0,0.85);
      backdrop-filter:blur(12px);
      border:1px solid rgba(168,85,247,0.5);
      border-radius:9999px;
      color:#fff;
      font-size:16px;
      font-weight:600;
      cursor:pointer;
      box-shadow:0 8px 32px rgba(0,0,0,0.5),0 0 20px rgba(168,85,247,0.2);
      transition:all 0.2s;
    ">
      <svg width="24" height="24" fill="none" stroke="currentColor" viewBox="0 0 24 24" style="flex-shrink:0;">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
      </svg>
      Click to unmute
    </button>
  `;
  document.body.appendChild(overlay);

  // Pulse animation on the button
  const btn = document.getElementById('unmute-btn');
  if (btn) {
    btn.addEventListener('mouseenter', () => {
      btn.style.background = 'rgba(168,85,247,0.3)';
      btn.style.borderColor = 'rgba(168,85,247,0.8)';
    });
    btn.addEventListener('mouseleave', () => {
      btn.style.background = 'rgba(0,0,0,0.85)';
      btn.style.borderColor = 'rgba(168,85,247,0.5)';
    });
  }
}

function hideUnmuteOverlay() {
  const overlay = document.getElementById('unmute-overlay');
  if (overlay) {
    overlay.style.transition = 'opacity 0.3s';
    overlay.style.opacity = '0';
    setTimeout(() => overlay.remove(), 300);
  }
}

// ===========================================
// VOLUME CONTROL (unchanged)
// ===========================================
let _volumeSaveTimeout = null;
function _debouncedSaveVolume(vol) {
  clearTimeout(_volumeSaveTimeout);
  _volumeSaveTimeout = setTimeout(() => localStorage.setItem('playerVolume', vol.toString()), 150);
}

let _volumeApplyTimeout = null, _pendingVolume = null;
function _throttledApplyVolume(vol) {
  _pendingVolume = vol;
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
  const el = document.getElementById('volume-value');
  if (el) el.textContent = volume + '%';

  const prev = window.playerState._prevIconVolume || -1;
  const iconChanged = (volume === 0) !== (prev === 0) ||
    (volume > 0 && volume < 50) !== (prev > 0 && prev < 50) ||
    (volume >= 50) !== (prev >= 50);

  if (iconChanged) {
    const icon = document.getElementById('volume-icon');
    if (icon) {
      if (volume === 0)
        icon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />`;
      else if (volume < 50)
        icon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />`;
      else
        icon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />`;
    }
    window.playerState._prevIconVolume = volume;
  }
  _debouncedSaveVolume(volume);
  _throttledApplyVolume(volume);
};

function applyVolumeToPlayer(vol) {
  try { window.playerState.ytPlayer?.unMute?.(); window.playerState.ytPlayer?.setVolume?.(vol); } catch (_) {}
  try { window.scWidget?.setVolume?.(vol); } catch (_) {}
}

window.toggleMute = function() {
  if (window.playerState.volume > 0) {
    window.playerState.previousVolume = window.playerState.volume;
    window.setPlayerVolume(0);
  } else {
    window.setPlayerVolume(window.playerState.previousVolume || 80);
  }
};

window.toggleVolumePopup = function() {
  document.getElementById('volume-popup')?.classList.toggle('hidden');
};

document.addEventListener('click', (e) => {
  const vc = document.getElementById('volume-control');
  const popup = document.getElementById('volume-popup');
  if (vc && popup && !vc.contains(e.target)) popup.classList.add('hidden');
});

// ===========================================
// YOUTUBE IFRAME API
// ===========================================
function loadYouTubeAPI() {
  if (window.YT?.Player) return Promise.resolve();
  return new Promise((resolve) => {
    if (document.querySelector('script[src*="youtube.com/iframe_api"]')) {
      const check = setInterval(() => { if (window.YT?.Player) { clearInterval(check); resolve(); } }, 100);
      return;
    }
    window.onYouTubeIframeAPIReady = () => resolve();
    const tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    document.getElementsByTagName('script')[0].parentNode.insertBefore(tag, document.getElementsByTagName('script')[0]);
  });
}
loadYouTubeAPI();

// ===========================================
// SOUNDCLOUD API
// ===========================================
(function() {
  if (window.SC?.Widget) return;
  const s = document.createElement('script');
  s.src = 'https://w.soundcloud.com/player/api.js';
  document.head.appendChild(s);
})();

// ===========================================
// LIVE POSITION HELPER
// ===========================================
// Recompute the expected playback position right now, accounting for clock offset.
function getLivePosition() {
  const sa = window.playerState.startedAt;
  if (!sa) return 0;
  const offset = window._clockOffset || 0;
  return Math.max(0, (Date.now() - sa - offset) / 1000);
}

// ===========================================
// SYNC PLAYER — the ONE entry point
// ===========================================
// Called on mount and whenever the server broadcasts a state change.
// Decides: create new player, or do nothing (queue-only update).
function syncPlayer(media, startedAt, serverNow, isHost) {
  console.log("[syncPlayer]", { type: media?.type, id: media?.media_id, startedAt, isHost });

  window.playerState.isHost = isHost;

  if (!media) {
    showPlaceholder();
    return;
  }

  const container = document.getElementById('media-container');
  if (!container) return;

  // If this is the exact same queue entry already playing AND the player DOM still exists, don't recreate.
  // We compare the unique track id (UUID), not media_id, so duplicate tracks in the queue
  // (same video/song queued multiple times) are correctly treated as different entries.
  // After LiveView navigation the DOM is destroyed but window.playerState persists,
  // so we must verify the actual player element is still in the page.
  const existingPlayer = document.getElementById('youtube-player-container') || document.getElementById('active-player');
  if (media.id && window.playerState.trackId === media.id && window.playerState.playerReady && existingPlayer) {
    return;
  }

  // Compute seek position:  how far into the track are we?
  // started_at is server ms epoch when position 0 began.
  // Adjust for clock difference: offset = Date.now() - serverNow
  const clockOffset = Date.now() - (serverNow || Date.now());
  const seekPosition = startedAt ? Math.max(0, (Date.now() - startedAt - clockOffset) / 1000) : 0;

  // Store clockOffset so onReady/READY can recompute a fresh position
  window._clockOffset = clockOffset;

  // Destroy old player
  try { window.playerState.ytPlayer?.destroy(); } catch (_) {}
  window.scWidget = null;

  const savedVolume = parseInt(localStorage.getItem('playerVolume') || '80', 10);
  // If user hasn't interacted yet, we must start muted (browser policy).
  // Once they click the overlay or anything on the page, we unmute.
  const startMuted = !window._userHasInteracted;
  window.playerState = {
    startedAt: startedAt,
    trackId: media.id,
    mediaId: media.media_id,
    mediaType: media.type,
    isHost: isHost,
    playerReady: false,
    endTriggered: false,
    ytPlayer: null,
    volume: savedVolume,
    previousVolume: window.playerState.previousVolume || savedVolume,
    _startMuted: startMuted,
    _createdAt: Date.now()  // Grace period: don't sync-seek until player has had time to load
  };

  // Show unmute overlay if we're starting muted
  if (startMuted) {
    showUnmuteOverlay();
  } else {
    hideUnmuteOverlay();
  }

  if (media.type === "youtube") {
    container.innerHTML = `
      <div class="absolute inset-0 bg-black" id="player-host">
        <div class="absolute left-0 right-0" style="top: 76px; bottom: 100px;">
          <div class="w-full h-full flex items-center justify-center">
            <div class="w-full h-full" style="max-width: calc((100vh - 176px) * 1.78);">
              <div id="youtube-player-container" class="w-full h-full"></div>
            </div>
          </div>
        </div>
      </div>`;
    initYouTubePlayer(media.media_id, Math.floor(seekPosition));
  } else if (media.type === "soundcloud") {
    const uid = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    container.innerHTML = `
      <div class="absolute inset-0 bg-gradient-to-br from-orange-900 via-red-900 to-purple-900 flex items-center justify-center" id="player-host">
        <div class="w-full h-full flex flex-col items-center justify-center px-6" style="padding-top: 70px; padding-bottom: 100px;">
          <div class="w-full flex items-center justify-center" style="max-width: 850px; max-height: 500px; height: 100%;">
            <iframe id="active-player" name="sc-player-${uid}" src="${media.embed_url}&_t=${uid}"
              frameborder="0" allow="autoplay; encrypted-media"
              class="w-full h-full rounded-xl shadow-2xl" loading="eager"></iframe>
          </div>
        </div>
      </div>`;
    const scIframe = document.getElementById('active-player');
    if (scIframe) {
      scIframe.addEventListener('load', () => initSoundCloud(seekPosition));
      setTimeout(() => { if (!window.playerState.playerReady) initSoundCloud(seekPosition); }, 3000);
    }
  }
}

// ===========================================
// YOUTUBE PLAYER
// ===========================================
function initYouTubePlayer(videoId, startSeconds) {
  if (!window.YT?.Player) {
    loadYouTubeAPI().then(() => initYouTubePlayer(videoId, startSeconds));
    return;
  }
  const el = document.getElementById('youtube-player-container');
  if (!el) return;

  window.playerState.ytPlayer = new YT.Player('youtube-player-container', {
    width: el.clientWidth || 800,
    height: el.clientHeight || 450,
    videoId,
    playerVars: { autoplay: 1, controls: 1, rel: 0, modestbranding: 1, playsinline: 1, start: startSeconds, enablejsapi: 1, origin: window.location.origin },
    events: {
      onReady: (e) => {
        window.playerState.playerReady = true;
        if (window.playerState._startMuted) {
          e.target.mute();
        } else {
          e.target.unMute();
          e.target.setVolume(window.playerState.volume);
        }
        // Recompute live position at the moment the player is actually ready,
        // since time has passed since syncPlayer computed the initial seekPosition.
        const livePos = getLivePosition();
        if (livePos > 1) {
          e.target.seekTo(livePos, true);
        }
        e.target.playVideo();
        // Host sends immediate progress report so the server recalibrates started_at right away
        if (window.playerState.isHost) {
          setTimeout(() => {
            try {
              const cur = e.target.getCurrentTime();
              const dur = e.target.getDuration();
              if (cur > 0) pushVideoProgress(cur, dur || 0);
            } catch (_) {}
          }, 500);
        }
      },
      onStateChange: (e) => {
        // Track ended
        if (e.data === 0 && !window.playerState.endTriggered) {
          window.playerState.endTriggered = true;
          pushVideoEnded();
        }
        // Auto-resume if paused unexpectedly
        if (e.data === 2 && !window.playerState.endTriggered) {
          setTimeout(() => { window.playerState.ytPlayer?.playVideo?.(); }, 500);
        }
      },
      onError: (e) => {
        console.error("[YT Player] Error:", e.data);
        // On error (video unavailable, embed blocked, etc.), advance the queue
        if (!window.playerState.endTriggered) {
          window.playerState.endTriggered = true;
          setTimeout(() => pushVideoEnded(), 1000);
        }
      }
    }
  });
}

// ===========================================
// SOUNDCLOUD PLAYER
// ===========================================
function initSoundCloud(startPosition) {
  const iframe = document.getElementById('active-player');
  if (!iframe || !window.SC?.Widget) {
    setTimeout(() => initSoundCloud(startPosition), 200);
    return;
  }
  if (window.playerState.playerReady) return;

  const widget = window.SC.Widget(iframe);

  widget.bind(window.SC.Widget.Events.READY, () => {
    window.playerState.playerReady = true;
    if (window.playerState._startMuted) {
      widget.setVolume(0);
    } else {
      widget.setVolume(window.playerState.volume);
    }
    // Recompute live position at the moment the widget is actually ready,
    // since time has passed since syncPlayer computed the initial startPosition.
    const livePos = getLivePosition();
    if (livePos > 1) {
      widget.seekTo(livePos * 1000);
    } else if (startPosition > 0) {
      widget.seekTo(startPosition * 1000);
    }
    widget.play();
    // Host sends immediate progress report so the server recalibrates started_at right away
    if (window.playerState.isHost) {
      setTimeout(() => {
        try {
          widget.getPosition((pos) => {
            const cur = pos / 1000;
            if (cur > 0) {
              widget.getDuration((d) => pushVideoProgress(cur, (d || 0) / 1000));
            }
          });
        } catch (_) {}
      }, 800);
    }
  });

  widget.bind(window.SC.Widget.Events.PLAY, () => {
    // If user interacted while the widget was loading, apply volume now
    if (window._userHasInteracted) {
      try { widget.setVolume(window.playerState.volume); } catch (_) {}
    }
  });

  widget.bind(window.SC.Widget.Events.FINISH, () => {
    if (!window.playerState.endTriggered) {
      window.playerState.endTriggered = true;
      pushVideoEnded();
    }
  });

  widget.bind(window.SC.Widget.Events.PLAY_PROGRESS, (data) => {
    if (data.relativePosition > 0.99 && !window.playerState.endTriggered) {
      window.playerState.endTriggered = true;
      pushVideoEnded();
    }
  });

  window.scWidget = widget;
}

// ===========================================
// PLACEHOLDER
// ===========================================
function showPlaceholder() {
  try { window.playerState.ytPlayer?.destroy(); } catch (_) {}
  window.playerState.ytPlayer = null;
  window.scWidget = null;
  window.playerState.mediaId = null;
  window.playerState.startedAt = null;
  window.playerState.playerReady = false;
  hideUnmuteOverlay();

  const c = document.getElementById('media-container');
  if (c) c.innerHTML = `
    <div class="flex items-center justify-center w-full h-full bg-gray-900" id="no-media-placeholder">
      <div class="text-center">
        <svg class="w-24 h-24 mx-auto mb-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-white text-xl mb-2">No media playing</p>
        <p class="text-gray-400 text-sm">Add a YouTube or SoundCloud track to get started</p>
      </div>
    </div>`;
}

// ===========================================
// PUSH EVENTS TO SERVER
// ===========================================
function pushVideoEnded() {
  console.log("[pushVideoEnded] Attempting to notify server");
  // Primary: use the window-level reference set by RoomHook
  if (window._roomHookPushEvent) {
    window._roomHookPushEvent("video_ended", {});
    return;
  }
  // Fallback 1: DOM element reference
  const hook = document.getElementById('room-container');
  if (hook?._phxHookPushEvent) {
    hook._phxHookPushEvent("video_ended", {});
    return;
  }
  // Fallback 2: find view directly
  if (window.liveSocket) {
    const view = document.querySelector('[data-phx-main]');
    const inst = view && window.liveSocket.getViewByEl(view);
    if (inst) inst.pushEvent("video_ended", {});
  }
}

function pushVideoProgress(currentTime, duration) {
  if (window._roomHookPushEvent) {
    window._roomHookPushEvent("video_progress", { current_time: currentTime, duration });
    return;
  }
  const hook = document.getElementById('room-container');
  if (hook?._phxHookPushEvent) {
    hook._phxHookPushEvent("video_progress", { current_time: currentTime, duration });
  }
}

// ===========================================
// SYNC LOOP (every 1.5s) — drift correction + progress reports
// ===========================================
setInterval(() => {
  if (!window.playerState.startedAt) return;
  if (window.playerState.endTriggered) return;

  const expected = getLivePosition();

  // Safety: if the player never became ready but we're well past the
  // estimated duration, tell the server the track ended so the queue advances.
  // This catches cases where the player fails to initialize after rejoin.
  if (!window.playerState.playerReady && expected > 200) {
    console.log("[syncLoop] Player never became ready and track duration exceeded, forcing advance");
    window.playerState.endTriggered = true;
    pushVideoEnded();
    return;
  }

  if (!window.playerState.playerReady) return;

  // Grace period: don't drift-correct seeks for the first 2.5s after player creation,
  // giving the player time to load and seek to the initial position.
  // Progress reports are ALWAYS sent regardless of grace period.
  const age = Date.now() - (window.playerState._createdAt || 0);
  const inGracePeriod = age < 2500;

  if (window.playerState.mediaType === "youtube" && window.playerState.ytPlayer) {
    try {
      const cur = window.playerState.ytPlayer.getCurrentTime();
      const dur = window.playerState.ytPlayer.getDuration();
      // If we know the real duration and we're past it, trigger end
      if (dur > 0 && cur >= dur - 0.5 && !window.playerState.endTriggered) {
        window.playerState.endTriggered = true;
        pushVideoEnded();
        return;
      }
      // Only drift-correct after grace period
      if (!inGracePeriod && Math.abs(expected - cur) > 3) window.playerState.ytPlayer.seekTo(expected, true);
      // Host reports progress to keep the server's started_at calibrated
      if (window.playerState.isHost && cur > 0) pushVideoProgress(cur, dur || 0);
    } catch (_) {}
  }

  if (window.playerState.mediaType === "soundcloud" && window.scWidget) {
    window.scWidget.isPaused((paused) => {
      if (paused && !window.playerState.endTriggered) window.scWidget.play();
    });
    window.scWidget.getPosition((pos) => {
      const cur = pos / 1000;
      // Only drift-correct after grace period
      if (!inGracePeriod && Math.abs(expected - cur) > 3) window.scWidget.seekTo(expected * 1000);
      // Host reports progress to keep the server's started_at calibrated
      if (window.playerState.isHost && cur > 0) {
        window.scWidget.getDuration((d) => pushVideoProgress(cur, (d || 0) / 1000));
      }
    });
  }
}, 1500);

// ===========================================
// LIVEVIEW HOOKS
// ===========================================
const ChatScroll = {
  mounted() {
    if (window._chatScrollPosition !== undefined) {
      this.el.scrollTop = window._chatScrollPosition;
      if (window._chatWasAtBottom) this.scrollToBottom();
    } else {
      this.scrollToBottom();
    }
    this.lastCount = this.msgCount();
    this.observer = new MutationObserver(() => {
      const c = this.msgCount();
      if (c > this.lastCount && !this.userScrolled) this.scrollToBottom();
      this.lastCount = c;
    });
    this.el.addEventListener('scroll', () => {
      const atBottom = this.el.scrollHeight - this.el.scrollTop <= this.el.clientHeight + 50;
      this.userScrolled = !atBottom;
      window._chatScrollPosition = this.el.scrollTop;
      window._chatWasAtBottom = atBottom;
    });
    this.observer.observe(this.el, { childList: true, subtree: true });
  },
  beforeUpdate() {
    window._chatScrollPosition = this.el.scrollTop;
    window._chatWasAtBottom = this.el.scrollHeight - this.el.scrollTop <= this.el.clientHeight + 50;
    this.savedCount = this.msgCount();
  },
  updated() {
    const c = this.msgCount();
    if (c === this.savedCount && window._chatScrollPosition !== undefined) {
      this.el.scrollTop = window._chatScrollPosition;
    } else if (c > this.savedCount && !this.userScrolled) {
      this.scrollToBottom();
    }
    this.lastCount = c;
  },
  destroyed() {
    window._chatScrollPosition = this.el.scrollTop;
    window._chatWasAtBottom = this.el.scrollHeight - this.el.scrollTop <= this.el.clientHeight + 50;
    this.observer?.disconnect();
  },
  msgCount() { return this.el.querySelector('#messages-container')?.children.length || 0; },
  scrollToBottom() { this.el.scrollTop = this.el.scrollHeight; }
};

const RoomHook = {
  mounted() {
    // Give pushEvent access to the rest of the JS
    this.el._phxHookPushEvent = (event, payload) => this.pushEvent(event, payload);
    // Also store a reference on window so pushVideoEnded always works
    window._roomHookPushEvent = (event, payload) => this.pushEvent(event, payload);

    // The ONE event handler for playback state
    this.handleEvent("sync_player", (data) => {
      syncPlayer(data.media, data.started_at, data.server_now, data.is_host);
    });

    this.handleEvent("force_play_soundcloud", () => {
      try { window.scWidget?.play?.(); } catch(_) {}
    });

    this.handleEvent("show_reaction", (data) => {
      const c = document.getElementById("reactions-container");
      if (!c) return;
      const r = document.createElement("div");
      r.className = "absolute animate-bounce-up text-5xl";
      r.style.left = `${Math.random() * 100 - 50}px`;
      r.style.textShadow = "0 0 10px rgba(255,255,255,0.5)";
      r.textContent = data.emoji;
      c.appendChild(r);
      setTimeout(() => r.remove(), 2500);
    });
  },
  destroyed() {
    window._roomHookPushEvent = null;
  }
};

const ClearOnSubmit = {
  mounted() {
    this.el.addEventListener("submit", () => {
      setTimeout(() => { const i = this.el.querySelector("input[type='text']"); if (i) i.value = ""; }, 10);
    });
  }
};

let Hooks = { ChatScroll, RoomHook, ClearOnSubmit };

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
});

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"});
window.addEventListener("phx:page-loading-start", () => topbar.show(300));
window.addEventListener("phx:page-loading-stop", () => topbar.hide());

liveSocket.connect();
window.liveSocket = liveSocket;

// ===========================================
// VOLUME UI INIT
// ===========================================
function initVolumeUI() {
  const vol = parseInt(localStorage.getItem('playerVolume') || '80', 10);
  if (window.playerState) window.playerState.volume = vol;
  const slider = document.getElementById('volume-slider');
  const label = document.getElementById('volume-value');
  if (slider) slider.value = vol;
  if (label) label.textContent = vol + '%';
}
document.addEventListener('DOMContentLoaded', initVolumeUI);
window.addEventListener('phx:page-loading-stop', () => setTimeout(initVolumeUI, 100));
