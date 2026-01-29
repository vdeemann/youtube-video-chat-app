// ULTIMATE MediaPlayer - Gets REAL durations and detects EXACT end
export const MediaPlayer = {
  mounted() {
    this.mediaType = this.el.dataset.mediaType;
    this.mediaId = this.el.dataset.mediaId;
    this.isHost = this.el.dataset.isHost === "true";
    this.hasEnded = false;
    this.realDuration = 0;
    
    console.log("============================================");
    console.log("🎬 MEDIA PLAYER MOUNTED");
    console.log("Type:", this.mediaType);
    console.log("Is Host:", this.isHost);
    console.log("============================================");
    
    // Handle reload events
    this.handleEvent("reload_iframe", ({media}) => {
      console.log("🔄 Reload - Next media:", media?.title || "null");
      if (media) {
        this.hasEnded = false;
        this.realDuration = 0;
        this.reloadMedia(media);
      }
    });
    
    // Initialize
    if (this.mediaType === "youtube") {
      this.initYouTube();
    } else if (this.mediaType === "soundcloud") {
      this.initSoundCloud();
    }
  },
  
  initYouTube() {
    console.log("🎥 Initializing YouTube...");
    
    if (!this.isHost) {
      console.log("Not host, skipping");
      return;
    }
    
    console.log("✅ IS HOST - Setting up end detection");
    
    this.messageHandler = (event) => {
      if (!event.origin.includes("youtube")) return;
      
      try {
        const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
        
        // Get duration when available
        if (data.info && data.info.duration && this.realDuration === 0) {
          this.realDuration = data.info.duration;
          console.log(`📏 Real duration: ${this.realDuration} seconds`);
          
          // Send real duration to server
          this.pushEvent("update_duration", {
            duration: Math.floor(this.realDuration),
            media_id: this.mediaId
          });
        }
        
        // Check for state changes
        if (data.event === "onStateChange") {
          const state = typeof data.info === 'number' ? data.info : data.info?.playerState;
          
          if (state === 0 && !this.hasEnded) {
            console.log("🎬🎬🎬 YOUTUBE ENDED! 🎬🎬🎬");
            this.hasEnded = true;
            this.sendEnd();
          } else if (state === 1) {
            console.log("▶️ Playing");
            this.hasEnded = false;
          }
        }
      } catch (e) {}
    };
    
    window.addEventListener("message", this.messageHandler);
    
    // Enable API
    setTimeout(() => {
      if (this.el?.contentWindow) {
        console.log("📡 Enabling YouTube API...");
        this.el.contentWindow.postMessage('{"event":"listening"}', '*');
        this.el.contentWindow.postMessage(
          '{"event":"command","func":"addEventListener","args":["onStateChange"]}',
          '*'
        );
        
        // Also request current state and duration
        this.requestInfo();
      }
    }, 2000);
  },
  
  requestInfo() {
    if (!this.el?.contentWindow) return;
    
    // Request duration
    this.el.contentWindow.postMessage(
      '{"event":"command","func":"getDuration","args":[]}',
      '*'
    );
    
    // Keep requesting until we get it
    if (this.realDuration === 0) {
      setTimeout(() => this.requestInfo(), 1000);
    }
  },
  
  initSoundCloud() {
    console.log("🎵 Initializing SoundCloud...");
    
    if (!this.isHost) {
      console.log("Not host, skipping");
      return;
    }
    
    console.log("✅ IS HOST - Setting up end detection");
    
    if (!window.SC?.Widget) {
      console.log("Loading SoundCloud API...");
      const script = document.createElement('script');
      script.src = 'https://w.soundcloud.com/player/api.js';
      script.onload = () => {
        console.log("✅ API loaded");
        setTimeout(() => this.setupSC(), 1000);
      };
      document.head.appendChild(script);
    } else {
      setTimeout(() => this.setupSC(), 1000);
    }
  },
  
  setupSC() {
    if (!window.SC?.Widget || !this.el) {
      setTimeout(() => this.setupSC(), 500);
      return;
    }
    
    console.log("Setting up SoundCloud widget...");
    this.widget = window.SC.Widget(this.el);
    
    this.widget.bind(window.SC.Widget.Events.READY, () => {
      console.log("✅ SoundCloud ready");
      
      // Get real duration
      this.widget.getDuration((ms) => {
        this.realDuration = ms / 1000;
        console.log(`📏 Real duration: ${this.realDuration} seconds`);
        
        // Send to server
        this.pushEvent("update_duration", {
          duration: Math.floor(this.realDuration),
          media_id: this.mediaId
        });
      });
      
      if (this.isHost) {
        setTimeout(() => this.widget.play(), 500);
      }
    });
    
    this.widget.bind(window.SC.Widget.Events.PLAY, () => {
      console.log("▶️ Playing");
      this.hasEnded = false;
    });
    
    if (this.isHost) {
      this.widget.bind(window.SC.Widget.Events.FINISH, () => {
        if (!this.hasEnded) {
          console.log("🎬🎬🎬 SOUNDCLOUD ENDED! 🎬🎬🎬");
          this.hasEnded = true;
          this.sendEnd();
        }
      });
    }
  },
  
  sendEnd() {
    console.log("============================================");
    console.log("📤 SENDING video_ended TO SERVER");
    console.log("Type:", this.mediaType);
    console.log("Duration was:", this.realDuration, "seconds");
    console.log("============================================");
    
    this.pushEvent("video_ended", {
      type: this.mediaType,
      mediaId: this.mediaId,
      duration: this.realDuration,
      timestamp: new Date().toISOString()
    });
  },
  
  reloadMedia(media) {
    console.log("🔄 Reloading:", media.title);
    
    // Cleanup
    if (this.messageHandler) {
      window.removeEventListener("message", this.messageHandler);
      this.messageHandler = null;
    }
    if (this.widget) {
      try {
        this.widget.unbind(window.SC.Widget.Events.READY);
        this.widget.unbind(window.SC.Widget.Events.PLAY);
        this.widget.unbind(window.SC.Widget.Events.FINISH);
      } catch (e) {}
      this.widget = null;
    }
    
    this.mediaType = media.type;
    this.mediaId = media.media_id;
    this.hasEnded = false;
    this.realDuration = 0;
    
    console.log("Updating iframe src");
    this.el.src = media.embed_url;
    
    setTimeout(() => {
      if (media.type === "youtube") {
        this.initYouTube();
      } else if (media.type === "soundcloud") {
        this.initSoundCloud();
      }
    }, 1500);
  },
  
  destroyed() {
    console.log("🗑️ Destroyed");
    if (this.messageHandler) {
      window.removeEventListener("message", this.messageHandler);
    }
  }
};

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

console.log("✅ MediaPlayer ULTIMATE - Real durations + Instant detection");
