#!/bin/bash
# Make executable: chmod +x diagnose_soundcloud.sh

echo "🎵 SoundCloud Integration Diagnostic Tool"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "\n${YELLOW}1. Checking Phoenix Server Status...${NC}"
if lsof -i :4000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Phoenix server is running on port 4000${NC}"
else
    echo -e "${RED}❌ Phoenix server is not running${NC}"
    echo "   Run: mix phx.server"
fi

echo -e "\n${YELLOW}2. Checking JavaScript Compilation...${NC}"
if [ -f "priv/static/assets/app.js" ]; then
    echo -e "${GREEN}✅ JavaScript assets compiled${NC}"
    # Check if MediaPlayer hook is present
    if grep -q "MediaPlayer" priv/static/assets/app.js 2>/dev/null; then
        echo -e "${GREEN}✅ MediaPlayer hook found in compiled assets${NC}"
    else
        echo -e "${RED}❌ MediaPlayer hook not found in compiled assets${NC}"
        echo "   Run: cd assets && npm run deploy"
    fi
else
    echo -e "${RED}❌ JavaScript assets not compiled${NC}"
    echo "   Run: cd assets && npm run deploy"
fi

echo -e "\n${YELLOW}3. Testing SoundCloud URL Parsing...${NC}"
cat > /tmp/test_soundcloud.exs << 'EOF'
# Test SoundCloud URL parsing
defmodule TestSoundCloud do
  def test_urls do
    urls = [
      "https://soundcloud.com/odesza/say-my-name-feat-zyra",
      "https://soundcloud.com/rickastley/never-gonna-give-you-up-4",
      "https://soundcloud.com/user-123/test-track?in=playlist"
    ]
    
    Enum.each(urls, fn url ->
      clean_url = url |> String.split(~r/[?#]/) |> List.first() |> String.trim()
      encoded = URI.encode_www_form_component(clean_url)
      embed = "https://w.soundcloud.com/player/?url=#{encoded}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
      
      IO.puts("\n📎 URL: #{url}")
      IO.puts("✨ Clean: #{clean_url}")
      IO.puts("🔗 Embed: #{String.slice(embed, 0..100)}...")
    end)
  end
end

TestSoundCloud.test_urls()
EOF

echo "Running URL parsing test..."
cd /Users/dee/youtube-video-chat-app && elixir /tmp/test_soundcloud.exs

echo -e "\n${YELLOW}4. Checking Database State...${NC}"
cat > /tmp/check_db.exs << 'EOF'
# Check database
try do
  Mix.Task.run("app.start")
  
  rooms = YoutubeVideoChatApp.Rooms.list_rooms()
  IO.puts("Found #{length(rooms)} rooms in database")
  
  if demo = Enum.find(rooms, & &1.slug == "demo-room") do
    IO.puts("Demo room exists with ID: #{demo.id}")
  else
    IO.puts("Demo room not found")
  end
rescue
  e -> IO.puts("Database error: #{inspect(e)}")
end
EOF

cd /Users/dee/youtube-video-chat-app && mix run /tmp/check_db.exs 2>/dev/null || echo -e "${YELLOW}⚠️  Could not check database${NC}"

echo -e "\n${YELLOW}5. Browser Test Instructions:${NC}"
echo "1. Open http://localhost:4000/test_soundcloud.html"
echo "2. Check if all 4 test players load correctly"
echo "3. Try the Widget API controls (Play/Pause/Get Info)"
echo "4. Test with your own SoundCloud URLs"

echo -e "\n${YELLOW}6. Manual Testing Steps:${NC}"
echo "1. Go to http://localhost:4000"
echo "2. Create or join a room"
echo "3. Click the queue button (☰) in the top right"
echo "4. Paste a SoundCloud URL like:"
echo "   https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "5. Check browser console for any errors (F12 -> Console)"

echo -e "\n${YELLOW}7. Common Issues & Solutions:${NC}"
echo -e "${YELLOW}Issue:${NC} SoundCloud player shows 'Something went wrong'"
echo -e "${GREEN}Fix:${NC} The track might not allow embedding. Try a different track."
echo ""
echo -e "${YELLOW}Issue:${NC} Player loads but doesn't auto-advance to next track"
echo -e "${GREEN}Fix:${NC} Only the room host can control playback. Make sure you're the host."
echo ""
echo -e "${YELLOW}Issue:${NC} JavaScript errors in console"
echo -e "${GREEN}Fix:${NC} Clear browser cache and reload the page."

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}Diagnostic complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
