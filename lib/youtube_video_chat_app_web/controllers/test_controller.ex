defmodule YoutubeVideoChatAppWeb.TestController do
  use YoutubeVideoChatAppWeb, :controller

  def soundcloud_test(conn, _params) do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>SoundCloud Integration Test</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          max-width: 1200px;
          margin: 0 auto;
          padding: 20px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          min-height: 100vh;
        }
        .container {
          background: white;
          border-radius: 10px;
          padding: 30px;
          box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 { color: #333; }
        .test-section {
          margin: 20px 0;
          padding: 20px;
          background: #f5f5f5;
          border-radius: 8px;
        }
        .test-section h2 {
          color: #ff5500;
          margin-top: 0;
        }
        .status {
          padding: 10px;
          border-radius: 5px;
          margin: 10px 0;
        }
        .success { background: #d4edda; color: #155724; }
        .error { background: #f8d7da; color: #721c24; }
        .warning { background: #fff3cd; color: #856404; }
        iframe {
          width: 100%;
          height: 400px;
          border: none;
          border-radius: 8px;
        }
        input {
          width: 100%;
          padding: 10px;
          margin: 10px 0;
          border: 2px solid #ddd;
          border-radius: 5px;
        }
        button {
          background: #ff5500;
          color: white;
          border: none;
          padding: 10px 20px;
          border-radius: 5px;
          cursor: pointer;
        }
        button:hover { background: #ff6600; }
        pre {
          background: #2d2d2d;
          color: #f8f8f2;
          padding: 15px;
          border-radius: 5px;
          overflow-x: auto;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🎵 SoundCloud Integration Test</h1>
        
        <div class="test-section">
          <h2>Test 1: Direct Embed (Should Always Work)</h2>
          <p>This is a direct SoundCloud embed - if this doesn't work, it's a network/browser issue:</p>
          <iframe
            src="https://w.soundcloud.com/player/?url=https%3A//soundcloud.com/odesza/say-my-name-feat-zyra&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
            scrolling="no"
            frameborder="no"
            allow="autoplay">
          </iframe>
          <div class="status success">✅ If you see a player above, SoundCloud embeds work in your browser</div>
        </div>

        <div class="test-section">
          <h2>Test 2: Dynamic Embed Test</h2>
          <input id="test-url" type="text" placeholder="Enter SoundCloud URL" value="https://soundcloud.com/rickastley/never-gonna-give-you-up-4">
          <button onclick="testEmbed()">Test Embed</button>
          <div id="dynamic-player" style="margin-top: 20px;"></div>
          <div id="status-message"></div>
        </div>

        <div class="test-section">
          <h2>Test 3: Widget API Test</h2>
          <iframe
            id="sc-widget"
            src="https://w.soundcloud.com/player/?url=https%3A//soundcloud.com/forss/flickermood&color=%23ff5500"
            scrolling="no"
            frameborder="no"
            allow="autoplay">
          </iframe>
          <div style="margin-top: 10px;">
            <button onclick="playWidget()">Play</button>
            <button onclick="pauseWidget()">Pause</button>
            <button onclick="getInfo()">Get Info</button>
          </div>
          <div id="widget-status" class="status warning">Widget not initialized</div>
        </div>

        <div class="test-section">
          <h2>Debug Info</h2>
          <pre id="debug-info">Loading...</pre>
        </div>
      </div>

      <script src="https://w.soundcloud.com/player/api.js"></script>
      <script>
        let widget = null;

        // Initialize widget
        window.addEventListener('load', function() {
          try {
            widget = SC.Widget(document.getElementById('sc-widget'));
            widget.bind(SC.Widget.Events.READY, function() {
              document.getElementById('widget-status').className = 'status success';
              document.getElementById('widget-status').textContent = '✅ Widget API initialized';
            });
            widget.bind(SC.Widget.Events.FINISH, function() {
              console.log('Track finished');
            });
          } catch (e) {
            document.getElementById('widget-status').className = 'status error';
            document.getElementById('widget-status').textContent = '❌ Failed to initialize widget: ' + e.message;
          }

          // Update debug info
          document.getElementById('debug-info').textContent = JSON.stringify({
            'User Agent': navigator.userAgent,
            'SoundCloud API Loaded': typeof SC !== 'undefined',
            'Widget Function Available': typeof SC?.Widget === 'function',
            'Current URL': window.location.href,
            'Protocol': window.location.protocol,
            'Timestamp': new Date().toISOString()
          }, null, 2);
        });

        function testEmbed() {
          const url = document.getElementById('test-url').value;
          const container = document.getElementById('dynamic-player');
          const status = document.getElementById('status-message');
          
          if (!url || !url.includes('soundcloud.com')) {
            status.className = 'status error';
            status.textContent = '❌ Please enter a valid SoundCloud URL';
            return;
          }
          
          const encodedUrl = encodeURIComponent(url);
          const embedUrl = `https://w.soundcloud.com/player/?url=${encodedUrl}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true`;
          
          container.innerHTML = `<iframe src="${embedUrl}" width="100%" height="400" frameborder="no" scrolling="no" allow="autoplay"></iframe>`;
          
          status.className = 'status success';
          status.textContent = '✅ Embed created! If player doesn\\'t load, the track may not allow embedding.';
        }

        function playWidget() {
          if (widget) {
            widget.play();
            console.log('Playing...');
          }
        }

        function pauseWidget() {
          if (widget) {
            widget.pause();
            console.log('Paused');
          }
        }

        function getInfo() {
          if (widget) {
            widget.getCurrentSound(function(sound) {
              alert('Track: ' + sound.title + ' by ' + sound.user.username);
            });
          }
        }
      </script>
    </body>
    </html>
    """
    
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end
end