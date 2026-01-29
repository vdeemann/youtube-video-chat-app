// SIMPLIFIED MediaPlayer - Focus on immediate video end detection
export const MediaPlayer = {
  mounted() {
    this.mediaType = this.el.dataset.mediaType;
    this.mediaId = this.el.dataset.mediaId;
    this.isHost = this.el.dataset.isHost === "true";
    
    console.log("============================================");
    console.log("🎬 MEDIA PLAYER MOUNTED");
    console.log("Type:", this.mediaType);
    console.log("Is Host:", this.isHost);
    console.log("============================================");
    
    // Handle reload events
    this.handleEvent("reload_iframe", ({media}) => {
      console.log("🔄 Reload event:", media);
      if (media) {
        this.reloadMedia(media);
      }
    });
    
    // Initialize player based on type
    if (this.mediaType === "youtube") {
      this.initYouTube();
    } else if (this.mediaType === "soundcloud") {
      this.initSoundCloud();
    }
  },
  
  initYouTube() {
    console.log("🎥 Initializing YouTube player");
    
    if (!this.isHost) {
      console.log("Not host, skipping end detection");
      return;
    }
    
    // Set up YouTube API message listener
    this.messageHandler = (event) => {
      if (!event.origin.includes("youtube")) return;
      
      try {
        const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
        
        // Check for video ended state
        if (data.event === "onStateChange") {
          const state = typeof data.info === 'number' ? data.info : data.info?.playerState;
          
          if (state === 0) {  // 0 = ended
            console.log("🎬 YOUTUBE VIDEO ENDED!");
            this.sendVideoEnded();
          } else if (state === 1) {
            console.log("▶️ YouTube playing");
          } else if (state === 2) {
            console.log("⏸️ YouTube paused");
          }
        }
      } catch (e) {
        // Ignore parse errors
      }
    };
    
    window.addEventListener("message", this.messageHandler);
    
    // Enable YouTube API after iframe loads
    setTimeout(() => {
      if (this.el && this.el.contentWindow) {
        try {
          // Enable API listening
          this.el.contentWindow.postMessage('{"event":"listening"}', '*');
          // Subscribe to state changes
          this.el.contentWindow.postMessage(
            '{"event":"command","func":"addEventListener","args":["onStateChange"]}',
            '*'
          );
          console.log("✅ YouTube API enabled");
        } catch (e) {
          console.error("❌ Failed to enable YouTube API:", e);
        }
      }
    }, 2000);
  },
  
  initSoundCloud() {
    console.log("🎵 Initializing SoundCloud player");
    
    if (!this.isHost) {
      console.log("Not host, skipping end detection");
      return;
    }
    
    // Load SoundCloud Widget API
    if (!window.SC || !window.SC.Widget) {
      console.log("Loading SoundCloud Widget API...");
      const script = document.createElement('script');
      script.src = 'https://w.soundcloud.com/player/api.js';
      script.async = true;
      script.onload = () => {
        console.log("✅ SoundCloud API loaded");
        setTimeout(() => this.setupSoundCloudWidget(), 1000);
      };
      document.head.appendChild(script);
    } else {
      setTimeout(() => this.setupSoundCloudWidget(), 1000);
    }
  },
  
  setupSoundCloudWidget() {
    if (!window.SC || !window.SC.Widget || !this.el) {
      console.log("SoundCloud not ready, retrying...");
      setTimeout(() => this.setupSoundCloudWidget(), 500);
      return;
    }
    
    console.log("Setting up SoundCloud widget");
    this.widget = window.SC.Widget(this.el);
    
    this.widget.bind(window.SC.Widget.Events.READY, () => {
      console.log("✅ SoundCloud widget ready");
      
      if (this.isHost) {
        // Auto-play for host
        setTimeout(() => {
          console.log("Auto-playing SoundCloud");
          this.widget.play();
        }, 500);
      }
    });
    
    this.widget.bind(window.SC.Widget.Events.PLAY, () => {
      console.log("▶️ SoundCloud playing");
    });
    
    if (this.isHost) {
      this.widget.bind(window.SC.Widget.Events.FINISH, () => {
        console.log("🎬 SOUNDCLOUD TRACK ENDED!");
        this.sendVideoEnded();
      });
    }
  },
  
  sendVideoEnded() {
    console.log("📤 Sending video_ended event to server");
    this.pushEvent("video_ended", {
      type: this.mediaType,
      mediaId: this.mediaId,
      timestamp: new Date().toISOString()
    });
  },
  
  reloadMedia(media) {
    console.log("Reloading media:", media.title);
    
    // Clean up current player
    if (this.messageHandler) {
      window.removeEventListener("message", this.messageHandler);
      this.messageHandler = null;
    }
    if (this.widget) {
      this.widget = null;
    }
    
    // Update media info
    this.mediaType = media.type;
    this.mediaId = media.media_id;
    
    // Update iframe
    this.el.src = media.embed_url;
    
    // Re-initialize after iframe loads
    setTimeout(() => {
      if (media.type === "youtube") {
        this.initYouTube();
      } else if (media.type === "soundcloud") {
        this.initSoundCloud();
      }
    }, 1500);
  },
  
  destroyed() {
    console.log("🗑️ MediaPlayer destroyed");
    if (this.messageHandler) {
      window.removeEventListener("message", this.messageHandler);
    }
  }
};

// Chat scroll hook
export const ChatScroll = {
  mounted() {
    this.scrollToBottom();
    this.observer = new MutationObserver(() => this.scrollToBottom());
    this.observer.observe(this.el, { childList: true, subtree: true });
  },
  
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  },
  
  destroyed() {
    if (this.observer) this.observer.disconnect();
  }
};

console.log("✅ MediaPlayer module loaded - Simplified for instant advancement");
