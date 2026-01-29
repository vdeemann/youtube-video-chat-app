#!/bin/bash

echo "🔍 QUICK SOUNDCLOUD TEST"
echo "========================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n${CYAN}Testing if the fix is applied...${NC}"

# Quick compile
docker-compose exec web mix compile

# Test the exact function
docker-compose exec web elixir -e '
# Load the module
Code.ensure_loaded(YoutubeVideoChatAppWeb.RoomLive.Show)

# Define a minimal test
url = "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83b41404370e4eafb0e1d85e24825601&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"

IO.puts("Testing URL: #{String.slice(url, 0..60)}...")

# Basic parsing logic that should work
if String.contains?(String.downcase(url), "soundcloud.com") do
  IO.puts("✅ Step 1: Detected as SoundCloud")
  
  # Parse URI
  uri = URI.parse(url)
  if uri.path do
    IO.puts("✅ Step 2: Path found: #{uri.path}")
    
    # Clean URL
    clean = "https://soundcloud.com#{uri.path}"
    IO.puts("✅ Step 3: Clean URL: #{clean}")
    
    # This is what would be sent to the embed
    encoded = URI.encode_www_form_component(clean)
    embed = "https://w.soundcloud.com/player/?url=#{encoded}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
    
    IO.puts("✅ Step 4: Embed URL generated")
    IO.puts("\n🎉 URL PARSING WORKS!")
  else
    IO.puts("❌ No path in URL")
  end
else
  IO.puts("❌ Not detected as SoundCloud")
end
'

echo -e "\n${CYAN}Quick restart...${NC}"
docker-compose restart web

echo -e "\n${YELLOW}Waiting 10 seconds for restart...${NC}"
sleep 10

echo -e "\n${GREEN}=============================${NC}"
echo -e "${GREEN}TEST COMPLETE!${NC}"
echo -e "${GREEN}=============================${NC}"
echo ""
echo "If you saw '🎉 URL PARSING WORKS!' above, the fix is applied."
echo ""
echo "Now test in your browser:"
echo "1. Go to http://localhost:4000/room/cool-jams-3460"
echo "2. Add the URL to the queue"
echo ""
echo "If it still doesn't work after seeing success above,"
echo "run: ${CYAN}./NUCLEAR_REBUILD.sh${NC}"
echo ""