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
window.setPlayerVolume = function(value) {
  const volume = Math.max(0, Math.min(100, parseInt(value, 10)));
  window.playerState.volume = volume;
  localStorage.setItem('playerVolume', volume.toString());
  
  // Update the volume slider UI
  const slider = document.getElementById('volume-slider');
  if (slider) slider.value = volume;
  
  const volumeValue = document.getElementById('volume-value');
  if (volumeValue) volumeValue.textContent = volume + '%';
  
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
  
  // Apply to current player
  applyVolumeToPlayer(volume);
};

function applyVolumeToPlayer(volume) {
  // YouTube
  if (window.playerState.ytPlayer && typeof window.playerState.ytPlayer.setVolume === 'function') {
    try {
      window.playerState.ytPlayer.setVolume(volume);
      console.log('[Volume] Set YouTube volume to:', volume);
    } catch (e) {
      console.warn('[Volume] Failed to set YouTube volume:', e);
    }
  }
  
  // SoundCloud
  if (window.scWidget && typeof window.scWidget.setVolume === 'function') {
    try {
      window.scWidget.setVolume(volume);
      console.log('[Volume] Set SoundCloud volume to:', volume);
    } catch (e) {
      console.warn('[Volume] Failed to set SoundCloud volume:', e);
    }
  }
  
  // Bandcamp HTML5 audio
  if (window.playerState.bandcampAudio) {
    try {
      window.playerState.bandcampAudio.volume = volume / 100;
      console.log('[Volume] Set Bandcamp audio volume to:', volume / 100);
    } catch (e) {
      console.warn('[Volume] Failed to set Bandcamp volume:', e);
    }
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
// BANDCAMP TIMER START
// Called when host clicks "Start Timer" button after they've started playback
// ===========================================
window.startBandcampTimer = function() {
  console.log("[Bandcamp] User clicked start timer button");
  
  // Update the button to show it was clicked
  const btn = document.getElementById('bandcamp-start-btn');
  if (btn) {
    btn.innerHTML = '✅ Timer Running!';
    btn.disabled = true;
    btn.classList.remove('from-green-500', 'to-teal-500', 'hover:from-green-600', 'hover:to-teal-600');
    btn.classList.add('from-gray-500', 'to-gray-600', 'cursor-not-allowed');
  }
  
  // Start the server-side timer
  pushBandcampStarted();
};

// Alias for backward compatibility
window.startBandcampPlayback = window.startBandcampTimer;

function pushBandcampStarted() {
  console.log("[Bandcamp] Pushing bandcamp_started event to server");
  
  // Method 1: Try using the hook's pushEvent
  const hookEl = document.getElementById('room-container');
  if (hookEl && hookEl._phxHookPushEvent) {
    console.log("[Bandcamp] Using hook pushEvent method");
    hookEl._phxHookPushEvent("bandcamp_started", {});
    return;
  }
  
  // Method 2: Find the LiveView and push directly
  if (window.liveSocket) {
    const view = document.querySelector('[data-phx-main]');
    if (view) {
      const viewInstance = window.liveSocket.getViewByEl(view);
      if (viewInstance) {
        console.log("[Bandcamp] Using LiveView pushEvent method");
        viewInstance.pushEvent("bandcamp_started", {}, () => {
          console.log("[Bandcamp] bandcamp_started event pushed successfully");
        });
        return;
      }
    }
  }
  
  console.error("[Bandcamp] Could not push bandcamp_started event");
}

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
  // For hosts starting a new track, always start from the beginning
  // Only calculate elapsed time for viewers joining mid-playback
  const now = Date.now();
  let elapsed = 0;
  let isNewTrack = true; // Assume new track unless we determine otherwise
  
  if (serverStartedAt) {
    const rawElapsed = Math.floor((now - serverStartedAt) / 1000);
    // Only apply elapsed time if it's significant (> 10 seconds)
    // This prevents skipping the beginning due to network latency
    // when a host starts a new track. Use a generous threshold.
    if (rawElapsed > 10) {
      elapsed = rawElapsed;
      isNewTrack = false;
      console.log(`[Player] Joining mid-playback, seeking to: ${elapsed}s`);
    } else {
      console.log(`[Player] Starting fresh (elapsed ${rawElapsed}s is within new track threshold)`);
    }
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
    
    // Setup SoundCloud player after it loads
    setTimeout(() => initSoundCloud(elapsed, isHost), 1000);
    
  } else if (media.type === "bandcamp") {
    // Bandcamp - use HTML5 audio player if stream_url is available (supports autoplay!)
    // Fall back to iframe embed if no stream_url
    const uniqueId = `${now}_${Math.random().toString(36).substr(2, 9)}`;
    const hasStreamUrl = media.stream_url && media.stream_url.length > 0;
    
    console.log("[Bandcamp] Has stream URL:", hasStreamUrl);
    
    if (hasStreamUrl) {
      // Use HTML5 audio player with the direct stream URL - this supports autoplay!
      playerHtml = `
        <div class="relative w-full h-full bg-gradient-to-br from-cyan-900 via-teal-900 to-blue-900" id="player-host">
          <div class="absolute inset-0 flex items-center justify-center">
            <div class="w-full max-w-4xl px-8">
              <div class="text-center mb-6">
                <h2 class="text-white text-2xl font-bold mb-2">${media.title || 'Bandcamp Track'}</h2>
                <p class="text-cyan-300/70 text-sm">Bandcamp • Streaming</p>
              </div>
              
              <!-- Album art / visualizer area -->
              <div class="relative mx-auto mb-6" style="max-width: 400px;">
                <div class="aspect-square bg-gradient-to-br from-cyan-800 to-teal-900 rounded-2xl shadow-2xl flex items-center justify-center overflow-hidden">
                  ${media.thumbnail && !media.thumbnail.startsWith('data:') ? 
                    `<img src="${media.thumbnail}" alt="Album art" class="w-full h-full object-cover" onerror="this.style.display='none'"/>` :
                    `<div class="text-8xl">🎵</div>`
                  }
                  <!-- Audio visualizer overlay -->
                  <div id="bandcamp-visualizer" class="absolute inset-0 flex items-end justify-center gap-1 p-8 opacity-50">
                    <div class="w-2 bg-cyan-400 rounded-full animate-pulse" style="height: 20%; animation-delay: 0s;"></div>
                    <div class="w-2 bg-cyan-400 rounded-full animate-pulse" style="height: 40%; animation-delay: 0.1s;"></div>
                    <div class="w-2 bg-cyan-400 rounded-full animate-pulse" style="height: 60%; animation-delay: 0.2s;"></div>
                    <div class="w-2 bg-cyan-400 rounded-full animate-pulse" style="height: 35%; animation-delay: 0.3s;"></div>
                    <div class="w-2 bg-cyan-400 rounded-full animate-pulse" style="height: 80%; animation-delay: 0.4s;"></div>
                    <div class="w-2 bg-cyan-400 rounded-full animate-pulse" style="height: 50%; animation-delay: 0.5s;"></div>
                    <div class="w-2 bg-cyan-400 rounded-full animate-pulse" style="height: 70%; animation-delay: 0.6s;"></div>
                    <div class="w-2 bg-cyan-400 rounded-full animate-pulse" style="height: 45%; animation-delay: 0.7s;"></div>
                  </div>
                </div>
              </div>
              
              <!-- HTML5 Audio player -->
              <div class="bg-black/30 rounded-xl p-4">
                <audio 
                  id="bandcamp-audio"
                  src="${media.stream_url}"
                  autoplay
                  preload="auto"
                  class="w-full"
                  style="height: 40px;"
                  controls
                ></audio>
              </div>
              
              <!-- Progress info -->
              <div class="text-center mt-4">
                <p class="text-cyan-200/60 text-sm">🎧 Streaming with autoplay • Synced playback</p>
              </div>
            </div>
          </div>
        </div>
      `;
      
      container.innerHTML = playerHtml;
      
      // Initialize Bandcamp HTML5 audio player
      initBandcampAudio(elapsed, isHost, media.duration || 180);
      
    } else {
      // Fallback to iframe embed (no autoplay)
      playerHtml = `
        <div class="relative w-full h-full bg-gradient-to-br from-cyan-900 via-teal-900 to-blue-900" id="player-host">
          <div class="absolute inset-0 flex items-center justify-center">
            <div class="w-full max-w-4xl px-8">
              <div class="text-center mb-6">
                <h2 class="text-white text-2xl font-bold mb-2">${media.title || 'Bandcamp Track'}</h2>
                <p class="text-white/70 text-sm">Bandcamp</p>
              </div>
              
              <!-- Bandcamp iframe - always visible -->
              <div id="bandcamp-container" class="relative" style="height: 120px;">
                <iframe
                  id="bandcamp-player"
                  name="bc-player-${uniqueId}"
                  src="${media.embed_url}"
                  style="border: 0; width: 100%; height: 100%;"
                  seamless
                  allow="autoplay"
                ></iframe>
              </div>
              
              <!-- Instructions -->
              <div class="text-center mt-6">
                <p class="text-yellow-300 text-lg font-semibold mb-4 animate-pulse">
                  👆 Click the play button above to start
                </p>
                
                ${isHost ? `
                  <p class="text-white/60 text-sm mb-3">Then click below to start the auto-advance timer:</p>
                  <button 
                    id="bandcamp-start-btn"
                    onclick="window.startBandcampTimer()"
                    class="px-6 py-3 bg-gradient-to-r from-green-500 to-teal-500 hover:from-green-600 hover:to-teal-600 text-white font-bold rounded-full transition transform hover:scale-105 shadow-xl"
                  >
                    ⏱️ Start Timer (${Math.floor((media.duration || 180) / 60)}:${String((media.duration || 180) % 60).padStart(2, '0')})
                  </button>
                  <p class="text-white/40 text-xs mt-2">Timer auto-advances to next track when complete</p>
                ` : `
                  <p class="text-white/50 text-sm">Host will start the timer after playing</p>
                `}
              </div>
            </div>
          </div>
        </div>
      `;
      
      container.innerHTML = playerHtml;
      
      console.log("[Bandcamp] Iframe player created - user must manually click play");
      window.playerState.playerReady = true;
      window.playerState.bandcampDuration = media.duration || 180;
    }
  }
}

// ===========================================
// BANDCAMP HTML5 AUDIO INITIALIZATION
// ===========================================
function initBandcampAudio(startPosition, isHost, duration) {
  const audio = document.getElementById('bandcamp-audio');
  if (!audio) {
    console.error("[Bandcamp] Audio element not found");
    return;
  }
  
  console.log("[Bandcamp] Initializing HTML5 audio, start:", startPosition, "isHost:", isHost, "duration:", duration);
  
  // Store duration for end detection
  window.playerState.bandcampDuration = duration;
  window.playerState.bandcampAudio = audio;
  
  // Apply saved volume
  const savedVolume = window.playerState.volume;
  audio.volume = savedVolume / 100;
  console.log('[Bandcamp] Applied saved volume:', savedVolume);
  
  // Handle canplay event - seek to position and play
  audio.addEventListener('canplay', function onCanPlay() {
    console.log("[Bandcamp] Audio can play");
    window.playerState.playerReady = true;
    
    // Seek to current position if joining mid-track
    if (startPosition > 0 && startPosition < duration) {
      console.log("[Bandcamp] Seeking to position:", startPosition);
      audio.currentTime = startPosition;
    }
    
    // Try to play
    audio.play().then(() => {
      console.log("[Bandcamp] ✅ Autoplay successful!");
      // Auto-start the server timer since we're autoplaying
      if (isHost) {
        console.log("[Bandcamp] Host auto-starting timer");
        pushBandcampStarted();
      }
    }).catch(err => {
      console.log("[Bandcamp] Autoplay blocked:", err.message);
      // Show a play button overlay if autoplay is blocked
      showBandcampPlayOverlay(audio, isHost);
    });
    
    // Remove this listener after first trigger
    audio.removeEventListener('canplay', onCanPlay);
  });
  
  // Handle ended event
  audio.addEventListener('ended', () => {
    console.log("[Bandcamp] Audio ended, isHost:", window.playerState.isHost);
    if (window.playerState.isHost && !window.playerState.endTriggered) {
      console.log("[Bandcamp] 🚀 Host triggering queue advance!");
      window.playerState.endTriggered = true;
      pushVideoEnded();
    }
  });
  
  // Handle errors
  audio.addEventListener('error', (e) => {
    console.error("[Bandcamp] Audio error:", e);
  });
  
  // Handle timeupdate for near-end detection
  audio.addEventListener('timeupdate', () => {
    const remaining = duration - audio.currentTime;
    if (remaining < 2 && window.playerState.isHost && !window.playerState.endTriggered) {
      console.log("[Bandcamp] Near end - triggering advance");
      window.playerState.endTriggered = true;
      pushVideoEnded();
    }
  });
}

// Show play button overlay if autoplay is blocked
function showBandcampPlayOverlay(audio, isHost) {
  const container = document.getElementById('player-host');
  if (!container) return;
  
  const overlay = document.createElement('div');
  overlay.id = 'bandcamp-play-overlay';
  overlay.className = 'absolute inset-0 bg-black/50 flex items-center justify-center z-10 cursor-pointer';
  overlay.innerHTML = `
    <div class="text-center">
      <div class="w-24 h-24 mx-auto mb-4 rounded-full bg-cyan-500 flex items-center justify-center hover:bg-cyan-400 transition transform hover:scale-110">
        <svg class="w-12 h-12 text-white ml-2" fill="currentColor" viewBox="0 0 24 24">
          <path d="M8 5v14l11-7z"/>
        </svg>
      </div>
      <p class="text-white text-xl font-bold">Click to Play</p>
      <p class="text-white/60 text-sm mt-2">Browser requires user interaction to start audio</p>
    </div>
  `;
  
  overlay.addEventListener('click', () => {
    audio.play().then(() => {
      console.log("[Bandcamp] ✅ Manual play successful!");
      overlay.remove();
      if (isHost) {
        pushBandcampStarted();
      }
    }).catch(err => {
      console.error("[Bandcamp] Play failed:", err);
    });
  });
  
  container.appendChild(overlay);
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
    setTimeout(() => initSoundCloud(startPosition, isHost), 500);
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
  
  // Don't run sync during the first 15 seconds of a new track
  // This prevents the sync loop from interfering with initial playback
  const timeSinceStart = Date.now() - window.playerState.localPlaybackStartedAt;
  if (window.playerState.isNewTrack && timeSinceStart < 15000) {
    return; // Skip sync during initial playback period
  }
  
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
  
  // Bandcamp HTML5 audio sync
  if (window.playerState.mediaType === "bandcamp" && window.playerState.bandcampAudio) {
    const audio = window.playerState.bandcampAudio;
    try {
      const currentTime = audio.currentTime;
      const drift = Math.abs(expectedPos - currentTime);
      
      // Auto-resume if paused
      if (audio.paused && !window.playerState.endTriggered) {
        console.log("[Sync] Bandcamp paused - resuming");
        audio.play().catch(() => {});
      }
      
      // Resync if drift is too large
      if (drift > 5 && !audio.paused) {
        console.log(`[Sync] Bandcamp drift ${drift.toFixed(1)}s - resyncing`);
        audio.currentTime = expectedPos;
      }
    } catch(e) {
      // Audio might not be ready
    }
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
  setTimeout(initializeVolumeUI, 100);
});

// Watch for the volume control element to appear (for LiveView dynamic content)
const volumeObserver = new MutationObserver((mutations) => {
  const slider = document.getElementById('volume-slider');
  if (slider && slider.value === '80' && localStorage.getItem('playerVolume')) {
    initializeVolumeUI();
  }
});

// Start observing when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  volumeObserver.observe(document.body, { childList: true, subtree: true });
});

console.log("✅ Simple sync player loaded (with YouTube IFrame API)");
