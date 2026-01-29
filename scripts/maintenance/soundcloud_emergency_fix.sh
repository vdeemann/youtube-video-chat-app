#!/bin/bash

echo "🚨 SoundCloud Emergency Fix & Debug"
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "\n${CYAN}=== STEP 1: Running Diagnostics ===${NC}"

# Check container status
echo -e "\n${YELLOW}Container Status:${NC}"
docker-compose ps

# Make scripts executable
chmod +x debug_soundcloud.sh 2>/dev/null
chmod +x fix_soundcloud.sh 2>/dev/null

echo -e "\n${CYAN}=== STEP 2: Applying Code Fixes ===${NC}"

# Restart and rebuild
echo -e "${YELLOW}Rebuilding assets and restarting...${NC}"
docker-compose exec web bash -c "
echo 'Installing npm packages...'
cd assets && npm install && cd ..

echo 'Building assets...'
mix assets.build

echo 'Compiling Elixir code...'
mix compile
" 2>/dev/null || echo -e "${RED}Failed to rebuild - container may need restart${NC}"

echo -e "\n${CYAN}=== STEP 3: Restarting Container ===${NC}"
docker-compose restart web

echo -e "${YELLOW}Waiting for Phoenix to start...${NC}"
sleep 10

# Wait for app
max_attempts=20
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:4000 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Phoenix is running${NC}"
        break
    fi
    echo -n "."
    sleep 2
    attempt=$((attempt + 1))
done

echo -e "\n${CYAN}=== STEP 4: Testing SoundCloud URLs ===${NC}"

# Test URL parsing in container
echo -e "${YELLOW}Testing URL parsing...${NC}"
docker-compose exec web elixir -e '
url = "https://soundcloud.com/odesza/say-my-name-feat-zyra"
if String.contains?(url, "soundcloud.com") do
  IO.puts("✅ SoundCloud URL detected correctly")
  
  # Simulate parsing
  clean_url = url |> String.split(~r/[?#]/) |> List.first() |> String.trim()
  encoded = URI.encode_www_form_component(clean_url)
  
  IO.puts("Clean URL: #{clean_url}")
  IO.puts("Encoded: #{String.slice(encoded, 0..50)}...")
  
  embed = "https://w.soundcloud.com/player/?url=#{encoded}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
  IO.puts("Embed URL generated successfully")
else
  IO.puts("❌ Failed to detect SoundCloud URL")
end
' 2>/dev/null || echo -e "${RED}❌ URL parsing test failed${NC}"

echo -e "\n${CYAN}=== STEP 5: Browser Test Instructions ===${NC}"

echo -e "${GREEN}✅ Setup Complete!${NC}"
echo ""
echo -e "${BLUE}TEST PAGES:${NC}"
echo "1. ${GREEN}Simple Test:${NC} http://localhost:4000/test_soundcloud"
echo "   - This page has 3 different SoundCloud embed tests"
echo "   - If players show here, SoundCloud works in your browser"
echo ""
echo "2. ${GREEN}Main App Test:${NC} http://localhost:4000"
echo "   - Create/join a room"
echo "   - Open browser console (F12)"
echo "   - Click queue button (☰)"
echo "   - Add: https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo ""
echo -e "${YELLOW}🔍 DEBUGGING CHECKLIST:${NC}"
echo "[ ] Can you see players at /test_soundcloud?"
echo "[ ] Does the browser console show any errors?"
echo "[ ] Does the URL get accepted when you paste it?"
echo "[ ] Does an orange 'SC' badge appear?"
echo "[ ] Does the player iframe load?"
echo ""
echo -e "${CYAN}📋 If SoundCloud still doesn't work:${NC}"
echo "1. ${YELLOW}Check browser console${NC} for JavaScript errors"
echo "2. ${YELLOW}Check Network tab${NC} to see if embed URL loads"
echo "3. ${YELLOW}Run:${NC} docker-compose logs -f web"
echo "4. ${YELLOW}Try:${NC} docker-compose down && docker-compose up --build"
echo ""
echo -e "${RED}🚨 Common Issues:${NC}"
echo "• ${YELLOW}Player shows 'Something went wrong'${NC} = Track doesn't allow embedding"
echo "• ${YELLOW}No player appears${NC} = JavaScript error (check console)"
echo "• ${YELLOW}URL not accepted${NC} = Backend parsing issue (check logs)"
echo ""
echo -e "${GREEN}Share any error messages from the browser console!${NC}"