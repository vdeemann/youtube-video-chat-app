// Test script for floating chat
// Run this in the browser console when on a room page

// Function to send a test message
function sendTestMessage(text = "Test message! 🎉") {
  const input = document.querySelector('input[name="message"]');
  const form = input.closest('form');
  
  if (input && form) {
    input.value = text;
    form.dispatchEvent(new Event('submit', {bubbles: true, cancelable: true}));
    console.log('Test message sent:', text);
  } else {
    console.error('Could not find chat input form');
  }
}

// Function to check if floating messages are visible
function checkFloatingMessages() {
  const container = document.getElementById('floating-chat-container');
  if (container) {
    const messages = container.querySelectorAll('[id^="floating-msg-"]');
    console.log('Floating messages found:', messages.length);
    messages.forEach(msg => {
      const computed = window.getComputedStyle(msg);
      console.log('Message:', {
        id: msg.id,
        text: msg.textContent,
        display: computed.display,
        visibility: computed.visibility,
        opacity: computed.opacity,
        animation: computed.animation,
        transform: computed.transform,
        position: computed.position,
        zIndex: computed.zIndex
      });
    });
  } else {
    console.error('Floating chat container not found');
  }
}

// Function to manually inject a floating message for testing
function injectTestFloatingMessage() {
  const container = document.getElementById('floating-chat-container');
  if (container) {
    const testMsg = document.createElement('div');
    testMsg.id = 'test-floating-msg-' + Date.now();
    testMsg.className = 'absolute whitespace-nowrap text-white text-3xl font-bold drop-shadow-lg';
    testMsg.style.cssText = `
      opacity: 1;
      top: 50%;
      left: 100%;
      animation: float-across 10s linear forwards;
      z-index: 1000;
      position: absolute;
    `;
    testMsg.innerHTML = `
      <span class="bg-purple-600/50 px-4 py-2 rounded-full">
        🎉 INJECTED TEST MESSAGE 🎉
      </span>
    `;
    container.appendChild(testMsg);
    console.log('Test floating message injected');
    
    // Remove after animation
    setTimeout(() => {
      testMsg.remove();
      console.log('Test floating message removed');
    }, 10000);
  } else {
    console.error('Floating chat container not found');
  }
}

// Export functions to window for easy access
window.chatDebug = {
  sendTestMessage,
  checkFloatingMessages,
  injectTestFloatingMessage,
  
  // Auto test: send a message and check if it appears
  autoTest: function() {
    console.log('Starting auto test...');
    const testText = 'Auto test ' + Date.now();
    sendTestMessage(testText);
    
    // Check for floating messages after a short delay
    setTimeout(() => {
      console.log('Checking for floating messages...');
      checkFloatingMessages();
    }, 1000);
  }
};

console.log(`
🎉 Chat Debug Tools Loaded! 🎉

Available commands:
- chatDebug.sendTestMessage("Your message here") - Send a test message
- chatDebug.checkFloatingMessages() - Check visible floating messages
- chatDebug.injectTestFloatingMessage() - Manually inject a test message
- chatDebug.autoTest() - Run automatic test

Try: chatDebug.autoTest()
`);
