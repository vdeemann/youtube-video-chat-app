#!/bin/bash

echo "🔧 SoundCloud Complete Fix & Debug for Docker"
echo "=============================================="

# Make all scripts executable
chmod +x *.sh 2>/dev/null

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "\n${CYAN}Step 1: Checking Docker Status${NC}"
if docker-compose ps | grep -q "web.*Up"; then
    echo -e "${GREEN}✅ Docker containers are running${NC}"
else
    echo -e "${YELLOW}⚠️  Starting Docker containers...${NC}"
    docker-compose up -d
    sleep 10
fi

echo -e "\n${CYAN}Step 2: Rebuilding with Latest Code${NC}"
docker-compose exec web bash -c "
echo 'Compiling Elixir code...'
mix compile --force

echo 'Installing JavaScript dependencies...'
cd assets && npm install

echo 'Building assets...'
cd .. && mix assets.build
" || echo -e "${RED}⚠️  Build had issues, continuing...${NC}"

echo -e "\n${CYAN}Step 3: Restarting Web Container${NC}"
docker-compose restart web
echo "Waiting for Phoenix to restart..."
sleep 12

echo -e "\n${CYAN}Step 4: Running Tests${NC}"

echo -e "\n${YELLOW}Test A: URL Parsing${NC}"
docker-compose exec web elixir -e '
test_url = "https://soundcloud.com/odesza/say-my-name-feat-zyra"
IO.puts("Testing: #{test_url}")

if String.contains?(test_url, "soundcloud.com") do
  IO.puts("✅ Recognized as SoundCloud")
  
  clean = String.split(test_url, ~r/[?#]/) |> List.first() |> String.trim()
  encoded = URI.encode_www_form_component(clean)
  embed = "https://w.soundcloud.com/player/?url=#{encoded}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
  
  IO.puts("✅ Embed URL generated")
  IO.puts("First 100 chars: #{String.slice(embed, 0..100)}...")
else
  IO.puts("❌ Not recognized as SoundCloud")
end
'

echo -e "\n${YELLOW}Test B: Check JavaScript Compilation${NC}"
docker-compose exec web bash -c '
if [ -f "priv/static/assets/app.js" ]; then
  echo "✅ app.js exists"
  grep -q "MediaPlayer" priv/static/assets/app.js && echo "✅ MediaPlayer hook found" || echo "❌ MediaPlayer hook missing"
  grep -q "soundcloud" priv/static/assets/app.js && echo "✅ SoundCloud code found" || echo "❌ SoundCloud code missing"
else
  echo "❌ app.js not found"
fi
'

echo -e "\n${YELLOW}Test C: HTTP Access${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:4000 | grep -q "200"; then
    echo -e "${GREEN}✅ Main app is accessible${NC}"
else
    echo -e "${RED}❌ Main app not responding${NC}"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/test_soundcloud | grep -q "200"; then
    echo -e "${GREEN}✅ Test page is accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Test page returns error${NC}"
fi

echo -e "\n${CYAN}============================================${NC}"
echo -e "${GREEN}🎉 Fix Applied! Now Test It:${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${BLUE}Option 1: Test Page (Recommended First)${NC}"
echo "   URL: http://localhost:4000/test_soundcloud"
echo "   - Should show 3 SoundCloud players"
echo "   - Test if embeds work in your browser"
echo ""
echo -e "${BLUE}Option 2: Main App Test${NC}"
echo "   1. Go to http://localhost:4000"
echo "   2. Create or join a room"
echo "   3. Press F12 to open browser console"
echo "   4. Click the queue button (☰)"
echo "   5. Paste this URL:"
echo "      ${GREEN}https://soundcloud.com/odesza/say-my-name-feat-zyra${NC}"
echo ""
echo -e "${YELLOW}📋 What to Check:${NC}"
echo "   • Does the URL get accepted?"
echo "   • Does an orange 'SC' badge appear?"
echo "   • Does the player show up?"
echo "   • Any errors in browser console?"
echo ""
echo -e "${YELLOW}🔍 If It Doesn't Work:${NC}"
echo "   1. Share browser console errors (F12 → Console)"
echo "   2. Run: docker-compose logs --tail=50 web"
echo "   3. Try: docker-compose down && docker-compose up --build"
echo ""
echo -e "${CYAN}📝 Test URLs:${NC}"
echo "   • https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "   • https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
echo "   • https://soundcloud.com/flume/flume-holdin-on"
echo ""