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
      // Don't unmute mid-settle — settle completion restores the volume.
      if (window.playerState._settled) {
        window.scWidget.setVolume(window.playerState.volume);
      }
      // Nudge SoundCloud to re-engage audio by pausing and immediately playing
      window.scWidget.play();
    }
  } catch (_) {}
}

// Any user interaction on the page counts — use {once: true} so listeners
// are automatically removed after the first interaction (no lingering handlers).
['click', 'keydown', 'touchstart'].forEach(evt => {
  document.addEventListener(evt, markUserInteracted, { once: true, capture: true });
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

// One-time cleanup of the old learned "load compensation" values.  That
// predicted-latency approach overshot the seek target and accumulated across
// joins (a rejoin landed seconds ahead of live), so it's been removed in
// favor of loading directly at the live position and correcting once.
try { localStorage.removeItem('ytLoadComp'); localStorage.removeItem('scLoadComp'); } catch (_) {}

// ===========================================
// SYNC DIAGNOSTICS
// ===========================================
// Ring buffer of every player-sync decision.  Type syncLog() in the console
// (or copy(syncLog())) to get a timeline — this is the first thing to grab
// when a join misbehaves (restart loops, wrong position, silent player).
window._syncEvents = [];
function logSync(event, detail) {
  const entry = `${new Date().toISOString().slice(11, 23)} ${event}${detail ? ' ' + detail : ''}`;
  window._syncEvents.push(entry);
  if (window._syncEvents.length > 80) window._syncEvents.shift();
  console.log('[sync]', entry);
}
window.syncLog = () => window._syncEvents.join('\n');

// Loop detector: three player creations inside 20s is never normal.  When it
// happens, surface a one-click "Copy log" toast so the diagnostic timeline
// can be reported without opening DevTools.
window._createTimes = [];
function noteCreateForLoopDetector() {
  const now = Date.now();
  window._createTimes = window._createTimes.filter(t => now - t < 20000);
  window._createTimes.push(now);
  if (window._createTimes.length >= 3) showDiagToast();
}

function showDiagToast() {
  if (document.getElementById('diag-toast')) return;
  const el = document.createElement('div');
  el.id = 'diag-toast';
  el.style.cssText = 'position:fixed;bottom:110px;left:16px;z-index:200;display:flex;gap:10px;align-items:center;' +
    'padding:10px 14px;background:rgba(0,0,0,.9);border:1px solid rgba(239,68,68,.6);border-radius:12px;' +
    'color:#fff;font-size:13px;box-shadow:0 8px 24px rgba(0,0,0,.5);';
  el.innerHTML = '<span>Playback sync problem detected</span>' +
    '<button id="diag-copy" style="padding:4px 10px;border-radius:8px;background:#7c3aed;color:#fff;font-weight:600;cursor:pointer;border:0">Copy log</button>' +
    '<button id="diag-close" style="color:#9ca3af;cursor:pointer;background:none;border:0;font-size:14px">✕</button>';
  document.body.appendChild(el);
  document.getElementById('diag-copy').onclick = () => {
    try {
      navigator.clipboard.writeText(window.syncLog());
      document.getElementById('diag-copy').textContent = 'Copied!';
    } catch (_) {}
  };
  document.getElementById('diag-close').onclick = () => el.remove();
}

// ===========================================
// SETTLE-THEN-UNMUTE
// ===========================================
// Players always boot muted so the settling phase (load at the predicted
// position, possible correction seek) is never audible.  markSettled()
// runs once playback timing is confirmed: it restores audio (when the
// browser allows it) and sends the host's first progress report — reports
// before this point could recalibrate the room clock to a pre-seek
// position and rewind the room for everyone.  A failsafe timeout
// guarantees audio even if a player event goes missing.
function markSettled() {
  const ps = window.playerState;
  if (ps._settled) return;
  ps._settled = true;
  if (ps._unmuteFailsafe) {
    clearTimeout(ps._unmuteFailsafe);
    ps._unmuteFailsafe = null;
  }

  const canUnmute = !ps._startMuted || window._userHasInteracted;

  try {
    if (ps.ytPlayer) {
      if (canUnmute) {
        ps.ytPlayer.setVolume(ps.volume);
        ps.ytPlayer.unMute();
      }
      if (ps.isHost) {
        const cur = ps.ytPlayer.getCurrentTime?.();
        const dur = ps.ytPlayer.getDuration?.();
        if (cur > 0) pushVideoProgress(cur, dur || 0);
      }
    }
  } catch (_) {}

  try {
    if (window.scWidget) {
      window.scWidget.setVolume(canUnmute ? ps.volume : 0);
      if (ps.isHost) {
        window.scWidget.getPosition((pos) => {
          const cur = pos / 1000;
          if (cur > 0) window.scWidget.getDuration((d) => pushVideoProgress(cur, (d || 0) / 1000));
        });
      }
    }
  } catch (_) {}
}

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
// CHORD DISPLAY — live chord readout synced to playback
// ===========================================
// The server pushes "track_analysis" with the chord timeline for the
// current track: segments [{t: seconds, c: "Am"}, ...] sorted by t.
// Position comes from the same server-authoritative clock the player
// sync uses (startedAt + clockOffset), so the readout follows seeks
// and drift corrections for free.
let _chordSegments = [];
let _chordTicker = null;
let _chordIdx = 0;

function setChordSegments(segments) {
  _chordSegments = Array.isArray(segments) ? segments : [];
  _chordIdx = 0;
  updateChordDisplay();
  if (_chordSegments.length > 0) {
    if (!_chordTicker) _chordTicker = setInterval(updateChordDisplay, 500);
  } else if (_chordTicker) {
    clearInterval(_chordTicker);
    _chordTicker = null;
  }
}

function updateChordDisplay() {
  const el = document.getElementById('current-chord');
  if (!el) return;
  if (!_chordSegments.length || !window.playerState.startedAt) {
    el.textContent = '—';
    return;
  }
  const pos = getLivePosition();
  // Segments are sorted; walk from the last known index so this is O(1)
  // per tick, while still handling seeks in either direction.
  let i = Math.min(_chordIdx, _chordSegments.length - 1);
  while (i > 0 && _chordSegments[i].t > pos) i--;
  while (i < _chordSegments.length - 1 && _chordSegments[i + 1].t <= pos) i++;
  _chordIdx = i;
  const chord = _chordSegments[i].t <= pos ? _chordSegments[i].c : null;
  el.textContent = chord && chord !== 'N' ? chord : '—';
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

  // If this is the exact same queue entry already set up here, don't recreate.
  // Prefer the unique track id (UUID) so duplicate tracks in the queue (same
  // video/song queued multiple times) are treated as different entries — but
  // fall back to media_id + type when the id is absent (e.g. an older
  // persisted snapshot), so a duplicate event still dedupes instead of
  // recreating the player.
  //
  // We intentionally do NOT require playerReady here.  A duplicate sync_player
  // event (LiveView reconnect/remount, a re-broadcast, request_player_state)
  // arriving while the player is still loading must be a no-op — tearing the
  // player down and recreating it mid-load is what made a freshly-joined video
  // restart over and over during the first few seconds.  After LiveView
  // navigation the DOM is destroyed but window.playerState persists, so we
  // also verify the actual player element is still in the page.
  const ps = window.playerState;
  const sameEntry = media.id
    ? ps.trackId === media.id
    : (ps.mediaId === media.media_id && ps.mediaType === media.type);
  const existingPlayer = document.getElementById('youtube-player-container') || document.getElementById('active-player');
  if (sameEntry && existingPlayer) {
    logSync('kept', `same entry ${media.media_id} (dup sync_player ignored)`);
    return;
  }

  // Compute seek position:  how far into the track are we?
  // started_at is server ms epoch when position 0 began.
  // Adjust for clock difference: offset = Date.now() - serverNow
  const clockOffset = Date.now() - (serverNow || Date.now());
  const seekPosition = startedAt ? Math.max(0, (Date.now() - startedAt - clockOffset) / 1000) : 0;

  logSync('create', `${media.type} ${media.media_id} seek=${seekPosition.toFixed(1)}s ` +
    `prev=${ps.trackId || ps.mediaId || 'none'} sameEntry=${sameEntry} hadDom=${!!existingPlayer}`);
  noteCreateForLoopDetector();

  // Store clockOffset so onReady/READY can recompute a fresh position
  window._clockOffset = clockOffset;

  // Destroy old player
  try { clearTimeout(window.playerState._unmuteFailsafe); } catch (_) {}
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
    initYouTubePlayer(media.media_id, seekPosition);
  } else if (media.type === "soundcloud") {
    const uid = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    // Disable the widget's own autoplay: it would start from 0:00 before we
    // can position it.  We call play() ourselves once the widget is ready.
    const embedSrc = media.embed_url.replace('auto_play=true', 'auto_play=false');
    container.innerHTML = `
      <div class="absolute inset-0 bg-gradient-to-br from-orange-900 via-red-900 to-purple-900 flex items-center justify-center" id="player-host">
        <div class="w-full h-full flex flex-col items-center justify-center px-6" style="padding-top: 70px; padding-bottom: 100px;">
          <div class="w-full flex items-center justify-center" style="max-width: 850px; max-height: 500px; height: 100%;">
            <iframe id="active-player" name="sc-player-${uid}" src="${embedSrc}&_t=${uid}"
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

  // Mid-track joins boot a BARE player, then loadVideoById at the target
  // position in onReady.  playerVars.start is unreliably honored, which
  // showed up as "plays the beginning, then jumps"; loadVideoById fetches
  // the stream directly at the offset, so 0:00 frames never exist.
  // Tracks starting fresh keep the direct path — position 0 is correct.
  const midJoin = startSeconds > 1;

  window.playerState.ytPlayer = new YT.Player('youtube-player-container', {
    width: el.clientWidth || 800,
    height: el.clientHeight || 450,
    ...(midJoin ? {} : { videoId }),
    playerVars: { autoplay: 1, controls: 1, rel: 0, modestbranding: 1, playsinline: 1, enablejsapi: 1, origin: window.location.origin },
    events: {
      onReady: (e) => {
        window.playerState.playerReady = true;
        // Always boot muted — the settling phase shouldn't be audible.
        // markSettled() restores audio once timing is confirmed.
        e.target.mute();
        e.target.setVolume(window.playerState.volume);
        window.playerState._unmuteFailsafe = setTimeout(markSettled, 4000);
        if (midJoin && !window.playerState._loadedOnce) {
          // Load directly at the current live position: no 0:00 frames, and
          // no predicted offset that could overshoot on a later join.  Guard
          // so a duplicate onReady can never reload (which would look like a
          // restart).  Residual buffering drift is corrected once on PLAYING.
          window.playerState._loadedOnce = true;
          const target = Math.max(0, Math.floor(getLivePosition()));
          logSync('yt_ready', `loadVideoById @ ${target}s`);
          e.target.loadVideoById({ videoId: videoId, startSeconds: target });
        } else if (!midJoin) {
          logSync('yt_ready', 'fresh track, playVideo @ 0');
          e.target.playVideo();
        } else {
          logSync('yt_ready', 'duplicate onReady ignored (_loadedOnce)');
        }
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
        // First moment of actual playback: correct to the live position once
        // if we drifted during buffering, then reveal audio.  Audio stays
        // muted until this settles — either immediately (close enough) or on
        // the PLAYING event after the one correction seek.
        if (e.data === 1) {
          if (!window.playerState._playbackTuned) {
            window.playerState._playbackTuned = true;
            let corrected = false;
            try {
              const cur = e.target.getCurrentTime();
              const live = getLivePosition();
              if (window.playerState.startedAt && Math.abs(live - cur) > 3) {
                logSync('yt_playing', `cur=${cur.toFixed(1)} live=${live.toFixed(1)} -> correcting`);
                e.target.seekTo(live, true);
                corrected = true;
              } else {
                logSync('yt_playing', `cur=${cur.toFixed(1)} live=${live.toFixed(1)} in sync`);
              }
            } catch (_) {}
            if (!corrected) markSettled();
          } else {
            markSettled();
          }
        }
        // Track ended
        if (e.data === 0 && !window.playerState.endTriggered) {
          logSync('yt_ended', 'state 0');
          window.playerState.endTriggered = true;
          pushVideoEnded();
        }
        // Auto-resume only AFTER the initial settle — never during the fragile
        // load/seek window, where a stray resume could fight buffering and
        // look like the video restarting.
        if (e.data === 2 && window.playerState._settled && !window.playerState.endTriggered) {
          logSync('yt_autoresume', 'paused unexpectedly, resuming');
          setTimeout(() => { window.playerState.ytPlayer?.playVideo?.(); }, 500);
        }
      },
      onError: (e) => {
        logSync('yt_error', `${e.data} — unplayable, advancing`);
        console.error("[YT Player] Error:", e.data);
        // This player can never play (embed disabled, deleted, region lock).
        // Mark it dead so the sync loop stops seek-thrashing it (each seek
        // made the embed flash its first frames — the visible restart loop),
        // and advance the queue immediately, bypassing the ended grace
        // period (errors arrive within ~1s of creation).
        window.playerState.playerErrored = true;
        if (!window.playerState.endTriggered) {
          window.playerState.endTriggered = true;
          setTimeout(() => pushVideoEnded(true), 1000);
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
    // Autoplay is off in the embed URL and volume starts at 0 — nothing is
    // audible until the position is confirmed (PLAY_PROGRESS below).
    widget.setVolume(0);
    window.playerState._loadStartedAt = Date.now();
    window.playerState._unmuteFailsafe = setTimeout(markSettled, 5000);
    widget.play();
  });

  widget.bind(window.SC.Widget.Events.PLAY, () => {
    // Seek only AFTER playback has started — seekTo before playing is
    // unreliably honored by the widget (that was the rare
    // "restarts from the beginning" bug).
    if (!window.playerState._settled && !window.playerState._scSeekIssued) {
      window.playerState._scSeekIssued = true;
      const live = getLivePosition();
      if (live > 1) {
        window.playerState._scSeekAt = Date.now();
        widget.seekTo(live * 1000);
      } else {
        markSettled(); // track is at/near its start — nothing to correct
      }
    } else if (window.playerState._settled && window._userHasInteracted) {
      // Re-apply volume when playback resumes after a user gesture
      try { widget.setVolume(window.playerState.volume); } catch (_) {}
    }
  });

  widget.bind(window.SC.Widget.Events.FINISH, () => {
    if (!window.playerState.endTriggered) {
      window.playerState.endTriggered = true;
      pushVideoEnded();
    }
  });

  let _lastProgressCheck = 0;
  widget.bind(window.SC.Widget.Events.PLAY_PROGRESS, (data) => {
    // While settling: confirm the seek landed near the live position, and
    // reissue it if the widget swallowed it.
    if (!window.playerState._settled) {
      const posS = (data.currentPosition || 0) / 1000;
      const live = getLivePosition();
      if (!window.playerState.startedAt || Math.abs(posS - live) <= 2.5) {
        markSettled();
      } else if (window.playerState._scSeekIssued && Date.now() - (window.playerState._scSeekAt || 0) > 1500) {
        window.playerState._scSeekAt = Date.now();
        widget.seekTo(live * 1000);
      }
      return;
    }

    // Settled: throttled end-of-track detection — SoundCloud fires
    // PLAY_PROGRESS many times per second, so only check every 2s to
    // reduce CPU load on older hardware.
    const now = Date.now();
    if (now - _lastProgressCheck < 2000) return;
    _lastProgressCheck = now;
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
  logSync('placeholder', 'no media — player destroyed');
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
function pushVideoEnded(force = false) {
  // Grace period: don't report "ended" within the first 5 seconds after player
  // creation.  Newly-joined clients sometimes get a spurious state-0 / FINISH
  // event while the player is still loading and seeking to the live position.
  // `force` bypasses it for explicit player ERRORS (embed-blocked/unavailable
  // videos error within ~1s of creation and can never play — suppressing
  // their skip left the room stuck on a dead player for the track's full
  // duration, with the sync loop flashing it every 5s).
  const age = Date.now() - (window.playerState._createdAt || 0);
  if (!force && age < 5000) {
    logSync('ended_suppressed', `player only ${Math.round(age / 1000)}s old (grace period)`);
    window.playerState.endTriggered = false;   // allow a real ended event later
    return;
  }
  logSync('ended_sent', `track=${window.playerState.trackId || 'none'}${force ? ' (forced: player error)' : ''}`);

  // Include the track ID so the server can deduplicate (prevents stale reports
  // from a client that was still playing the previous track from skipping the new one).
  const trackId = window.playerState.trackId || null;
  console.log("[pushVideoEnded] Notifying server, trackId:", trackId);
  const payload = { track_id: trackId };

  // Primary: use the window-level reference set by RoomHook
  if (window._roomHookPushEvent) {
    window._roomHookPushEvent("video_ended", payload);
    return;
  }
  // Fallback 1: DOM element reference
  const hook = document.getElementById('room-container');
  if (hook?._phxHookPushEvent) {
    hook._phxHookPushEvent("video_ended", payload);
    return;
  }
  // Fallback 2: find view directly
  if (window.liveSocket) {
    const view = document.querySelector('[data-phx-main]');
    const inst = view && window.liveSocket.getViewByEl(view);
    if (inst) inst.pushEvent("video_ended", payload);
  }
}

function pushVideoProgress(currentTime, duration) {
  // Never report position before playback has settled — a pre-seek report
  // would recalibrate the room clock to the wrong position and rewind the
  // track for everyone in the room (persisted, too).
  if (!window.playerState._settled) return;
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
// SYNC LOOP — drift correction + progress reports
// ===========================================
// Runs every 5s. Hosts report progress every tick (5s).
// Non-hosts only drift-correct every 3rd tick (15s) to save CPU.
let _syncLoopCount = 0;
setInterval(() => {
  _syncLoopCount++;
  if (!window.playerState.startedAt) return;
  if (window.playerState.endTriggered) return;
  // A player that errored (embed-blocked/unavailable video) can never play —
  // seeking it just makes the embed flash over and over.  Leave it alone;
  // the error handler has already requested a queue advance.
  if (window.playerState.playerErrored) return;

  const expected = getLivePosition();

  // Safety: if the player never became ready but we're well past the
  // estimated duration, tell the server the track ended so the queue advances.
  // This catches cases where the player fails to initialize after rejoin.
  if (!window.playerState.playerReady && expected > 200) {
    logSync('force_advance', `player never ready, expected=${Math.round(expected)}s`);
    window.playerState.endTriggered = true;
    pushVideoEnded();
    return;
  }

  if (!window.playerState.playerReady) return;

  // Non-hosts only run every 3rd tick (effectively every 15s instead of 5s)
  if (!window.playerState.isHost && _syncLoopCount % 3 !== 0) return;

  // Grace period: don't drift-correct seeks for the first 2.5s after player creation,
  // giving the player time to load and seek to the initial position.
  // Progress reports are ALWAYS sent regardless of grace period.
  const age = Date.now() - (window.playerState._createdAt || 0);
  const inGracePeriod = age < 2500;

  const mediaType = window.playerState.mediaType;

  // Early-exit: only check the active player type (not both)
  if (mediaType === "youtube" && window.playerState.ytPlayer) {
    try {
      const cur = window.playerState.ytPlayer.getCurrentTime();
      const dur = window.playerState.ytPlayer.getDuration();
      // If we know the real duration and we're past it, trigger end
      if (dur > 0 && cur >= dur - 0.5 && !window.playerState.endTriggered) {
        window.playerState.endTriggered = true;
        pushVideoEnded();
        return;
      }
      // Only drift-correct after grace period, with a wider threshold (5s)
      if (!inGracePeriod && Math.abs(expected - cur) > 5) {
        logSync('drift_seek', `yt cur=${cur.toFixed(1)} expected=${expected.toFixed(1)}`);
        window.playerState.ytPlayer.seekTo(expected, true);
      }
      // Host reports progress to keep the server's started_at calibrated
      if (window.playerState.isHost && cur > 0) pushVideoProgress(cur, dur || 0);
    } catch (_) {}
  } else if (mediaType === "soundcloud" && window.scWidget) {
    window.scWidget.isPaused((paused) => {
      if (paused && !window.playerState.endTriggered) window.scWidget.play();
    });
    window.scWidget.getPosition((pos) => {
      const cur = pos / 1000;
      // Only drift-correct after grace period, with a wider threshold (5s)
      if (!inGracePeriod && Math.abs(expected - cur) > 5) window.scWidget.seekTo(expected * 1000);
      // Host reports progress to keep the server's started_at calibrated
      if (window.playerState.isHost && cur > 0) {
        window.scWidget.getDuration((d) => pushVideoProgress(cur, (d || 0) / 1000));
      }
    });
  }
}, 5000);

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
    // Cached images can finish before any 'load' listener attaches, so the
    // heights they add would leave a bottom-pinned view stranded above the
    // newest messages.  Re-pin after layout settles.
    if (window._chatWasAtBottom !== false) {
      requestAnimationFrame(() => this.scrollToBottom());
      setTimeout(() => { if (!this.userScrolled) this.scrollToBottom(); }, 200);
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
    // Chat images (GIFs) finish loading after DOM patches and expand the
    // scroll height; when pinned to the bottom, stay pinned as they load.
    // 'load' doesn't bubble, so listen in the capture phase.
    this.el.addEventListener('load', () => {
      if (window._chatWasAtBottom && !this.userScrolled) this.scrollToBottom();
    }, true);
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
      // Re-render without new messages (e.g. toggling the queue panel):
      // if we were pinned to the bottom, stay pinned — restoring a raw
      // scrollTop mis-lands when images haven't re-laid-out yet.
      if (window._chatWasAtBottom) this.scrollToBottom();
      else this.el.scrollTop = window._chatScrollPosition;
    } else if (c > this.savedCount && !this.userScrolled) {
      this.scrollToBottom();
    }
    this.lastCount = c;
  },
  destroyed() {
    // A detached element reads scrollTop/scrollHeight as 0 — don't clobber
    // the last good position saved by the scroll listener with zeros.
    if (this.el.scrollHeight > 0) {
      window._chatScrollPosition = this.el.scrollTop;
      window._chatWasAtBottom = this.el.scrollHeight - this.el.scrollTop <= this.el.clientHeight + 50;
    }
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

    // Chord timeline for the current track.  Pushed on mount and on every
    // track change (empty when no analysis exists, clearing stale chords).
    this.handleEvent("track_analysis", (data) => {
      setChordSegments(data.chords || []);
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
    setChordSegments([]);
  }
};

const ClearOnSubmit = {
  mounted() {
    this.el.addEventListener("submit", () => {
      setTimeout(() => { const i = this.el.querySelector("input[type='text']"); if (i) i.value = ""; }, 10);
    });
  }
};

// ===========================================
// "PASS THE AUX" WORDMARK TOSS (home page)
// ===========================================
// GSAP toss: "Pass the" arcs in from the left, then "Aux" slides in with a
// gradient reveal and jams into its socket.  Plays on a visitor's very
// first landing, then again every 6th landing (1st, 7th, 13th, ...) so the
// page stays fresh for regulars without being a carnival.  Degrades to the
// static title when GSAP is unavailable or the user prefers reduced motion.
const PassTheAuxToss = {
  mounted() {
    const phrase = this.el.querySelector("#pta-phrase");
    const aux = this.el.querySelector("#pta-aux");
    if (!phrase || !aux || !window.gsap) return;

    let count = 1;
    try {
      count = (parseInt(localStorage.getItem("ptaLandings") || "0", 10) || 0) + 1;
      localStorage.setItem("ptaLandings", String(count));
    } catch (_) {}

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced || count % 6 !== 1) return; // static title this visit

    const gsap = window.gsap;
    const tl = gsap.timeline({ paused: true });

    tl.set(phrase, { x: -180, y: -100, rotation: -7, autoAlpha: 1 }, 0)
      .to(phrase, { x: 0, duration: 0.65, ease: "power1.inOut" }, 0)
      .to(phrase, { y: 0, duration: 0.65, ease: "power2.in" }, 0)
      .to(phrase, { rotation: 0, duration: 0.65, ease: "power1.out" }, 0)
      .to(phrase, { y: 8, duration: 0.09, ease: "power1.in" }, 0.65)
      .to(phrase, { y: 0, duration: 0.24, ease: "power2.out" }, 0.74);

    const seat = 1.05;
    tl.set(aux, { x: -230, autoAlpha: 1, "--fs": "55%", "--fe": "175%" }, seat)
      .to(aux, { x: 0, duration: 0.5, ease: "power2.in" }, seat)
      .to(aux, { "--fs": "-120%", "--fe": "0%", duration: 0.42, ease: "power1.out" }, seat + 0.05)
      .to(aux, { scaleX: 0.84, duration: 0.07, transformOrigin: "right center" }, seat + 0.5)
      .to(aux, { scaleX: 1, x: -4, duration: 0.1, ease: "power1.out" }, seat + 0.57)
      .to(aux, { x: 0, duration: 0.35, ease: "elastic.out(1, 0.5)" }, seat + 0.67)
      .to(phrase, { x: 6, duration: 0.08, ease: "power2.in" }, seat + 0.5)
      .to(phrase, { x: 0, duration: 0.5, ease: "elastic.out(1, 0.45)" }, seat + 0.58);

    // The static title has been showing since the server render (progressive
    // enhancement) — hide both words at the last moment, then play.
    gsap.set([phrase, aux], { autoAlpha: 0 });
    tl.play();
  }
};

let Hooks = { ChatScroll, RoomHook, ClearOnSubmit, PassTheAuxToss };

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
