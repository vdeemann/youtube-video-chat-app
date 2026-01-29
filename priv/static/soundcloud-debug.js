// Debug script for SoundCloud integration
// Paste this in your browser console while on the room page

console.log("=== SoundCloud Debug Info ===");

// Check if MediaPlayer hook is loaded
const mediaPlayerElements = document.querySelectorAll('[phx-hook="MediaPlayer"]');
console.log("MediaPlayer elements found:", mediaPlayerElements.length);

// Check current media info
const iframe = document.querySelector('#soundcloud-iframe');
if (iframe) {
    console.log("SoundCloud iframe found!");
    console.log("Current src:", iframe.src);
    
    // Parse the URL to see what track is being loaded
    try {
        const url = new URL(iframe.src);
        const trackUrl = url.searchParams.get('url');
        console.log("Track URL:", decodeURIComponent(trackUrl || 'none'));
    } catch (e) {
        console.log("Could not parse iframe URL");
    }
} else {
    console.log("No SoundCloud iframe found");
}

// Check for YouTube iframe
const ytIframe = document.querySelector('#youtube-iframe');
if (ytIframe) {
    console.log("YouTube iframe found with src:", ytIframe.src);
}

// Test SoundCloud embed generation
function testSoundCloudEmbed(url) {
    const encodedUrl = encodeURIComponent(url);
    const embedUrl = `https://w.soundcloud.com/player/?url=${encodedUrl}&color=%23ff5500&auto_play=false&hide_related=false&show_comments=true&show_user=true&show_reposts=false&show_teaser=true&visual=true`;
    console.log("Generated embed URL:", embedUrl);
    return embedUrl;
}

// Example test
console.log("\nTest embed generation:");
testSoundCloudEmbed("https://soundcloud.com/platform/sama");

console.log("\n=== Instructions ===");
console.log("1. Try adding this URL to the queue:");
console.log("   https://soundcloud.com/platform/sama");
console.log("2. Check if the track appears in the queue with an orange badge");
console.log("3. If it doesn't play, check for errors above");
console.log("4. You can also test with any public SoundCloud track URL");
