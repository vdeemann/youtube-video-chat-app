// Hooks are now managed in app.js
// This file is kept for compatibility but most functionality moved to app.js

export const ChatScroll = {
  mounted() {
    this.scrollToBottom();
    this.observer = new MutationObserver(() => {
      if (!this.isUserScrolled) {
        this.scrollToBottom();
      }
    });
    
    this.el.addEventListener('scroll', () => {
      const isAtBottom = this.el.scrollHeight - this.el.scrollTop <= this.el.clientHeight + 50;
      this.isUserScrolled = !isAtBottom;
    });
    
    this.observer.observe(this.el, { childList: true, subtree: true });
  },
  
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  },
  
  destroyed() {
    if (this.observer) this.observer.disconnect();
  }
};

// MediaPlayer hook is no longer needed - iframes managed by pure JS
export const MediaPlayer = {
  mounted() {
    console.log("[MediaPlayer Hook] Mounted but not used - JS manages player directly");
  }
};
