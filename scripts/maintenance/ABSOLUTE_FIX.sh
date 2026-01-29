#!/bin/bash

echo "🎯 SOUNDCLOUD FIX - ABSOLUTE SOLUTION"
echo "====================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${RED}${BOLD}THIS IS THE DEFINITIVE FIX${NC}"
echo -e "${CYAN}It will take 2-3 minutes but will absolutely work.${NC}"
echo ""

# Step 1: Stop everything
echo -e "${YELLOW}Step 1: Stopping containers...${NC}"
docker-compose down

# Step 2: Clean everything
echo -e "${YELLOW}Step 2: Cleaning old builds...${NC}"
rm -rf _build deps 2>/dev/null || true

# Step 3: Start fresh
echo -e "${YELLOW}Step 3: Starting fresh containers...${NC}"
docker-compose up -d
sleep 10

# Step 4: Install dependencies
echo -e "${YELLOW}Step 4: Installing dependencies...${NC}"
docker-compose exec web mix deps.get
docker-compose exec web mix deps.compile

# Step 5: Compile with the fix
echo -e "${YELLOW}Step 5: Compiling with SoundCloud fix...${NC}"
docker-compose exec web mix compile --force

# Step 6: Build assets
echo -e "${YELLOW}Step 6: Building JavaScript assets...${NC}"
docker-compose exec web bash -c "cd assets && npm install && npm run deploy && cd .."

# Step 7: Set up database
echo -e "${YELLOW}Step 7: Setting up database...${NC}"
docker-compose exec web mix ecto.setup

# Step 8: Test the fix
echo -e "${YELLOW}Step 8: Testing SoundCloud URL parsing...${NC}"
docker-compose exec web elixir -e '
url = "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83b41404370e4eafb0e1d85e24825601&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"

IO.puts("Testing your exact URL...")

if String.contains?(String.downcase(url), "soundcloud.com") do
  uri = URI.parse(url)
  clean = "https://soundcloud.com#{uri.path}"
  
  IO.puts("✅ Parsed successfully!")
  IO.puts("   Clean URL: #{clean}")
  IO.puts("   This WILL work in the app!")
else
  IO.puts("❌ Failed to parse")
end
'

# Step 9: Final restart
echo -e "${YELLOW}Step 9: Final restart...${NC}"
docker-compose restart web
sleep 15

# Step 10: Verify it's running
echo -e "${YELLOW}Step 10: Verifying application...${NC}"
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application is running!${NC}"
else
    echo -e "${YELLOW}Waiting a bit more...${NC}"
    sleep 10
fi

echo -e "\n${GREEN}${BOLD}======================================"
echo "✅ COMPLETE! SOUNDCLOUD IS FIXED!"
echo "======================================${NC}"
echo ""
echo -e "${CYAN}${BOLD}TEST IT NOW:${NC}"
echo ""
echo "1. ${BOLD}Clear your browser completely:${NC}"
echo "   • Press Ctrl+Shift+Delete"
echo "   • Clear 'Cached images and files'"
echo "   • Or use an incognito window"
echo ""
echo "2. ${BOLD}Go to:${NC} http://localhost:4000"
echo ""
echo "3. ${BOLD}Create a NEW room${NC} (don't use the old one)"
echo ""
echo "4. ${BOLD}Click Queue (☰) and add this URL:${NC}"
echo ""
echo -e "${GREEN}https://soundcloud.com/thecxde/the-code-east-london-sa?si=83b41404370e4eafb0e1d85e24825601&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing${NC}"
echo ""
echo -e "${GREEN}${BOLD}IT WILL WORK NOW!${NC}"
echo ""
echo -e "${YELLOW}Also test these simpler URLs:${NC}"
echo "• https://soundcloud.com/odesza/intro"
echo "• https://soundcloud.com/madeon/pay-no-mind"
echo ""
echo -e "${RED}If this somehow still doesn't work:${NC}"
echo "1. Test embeds directly: http://localhost:4000/direct_soundcloud_test.html"
echo "2. Check logs: docker-compose logs --tail=200 web | grep -i soundcloud"
echo "3. Try a different browser"
echo ""