// Simplified YouTube player hook for iframe-based player
// This is kept minimal to avoid conflicts with LiveView updates
export const YouTubePlayer = {
  mounted() {
    console.log("YouTube player iframe mounted");
  },
  
  destroyed() {
    console.log("YouTube player iframe destroyed");
  }
}
