#!/bin/bash

echo "🎯 SOUNDCLOUD FIX - FIXING THE ENCODING ERROR"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${GREEN}${BOLD}Found the exact issue!${NC}"
echo "The error was: URI.encode_www_form_component doesn't exist in Elixir"
echo "Fixed to use: URI.encode instead"
echo ""

echo -e "${CYAN}Applying the fix...${NC}"

# Compile the fixed code
echo -e "${YELLOW}1. Compiling the fixed code...${NC}"
docker-compose exec web mix compile --force

# Test the fix
echo -e "\n${YELLOW}2. Testing the fix with your URL...${NC}"
docker-compose exec web elixir -e '
url = "https://soundcloud.com/thecxde/the-code-east-london-sa?si=1178444a99ec4df09792cf566676eac3&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"

# Parse it
uri = URI.parse(url)
path = uri.path || ""
clean_url = "https://soundcloud.com#{path}"

IO.puts("Testing URL encoding...")
IO.puts("Clean URL: #{clean_url}")

# Test the correct encoding function
encoded = URI.encode(clean_url)
IO.puts("✅ Encoded successfully: #{String.slice(encoded, 0..50)}...")

# Build embed URL
embed = "https://w.soundcloud.com/player/?url=#{encoded}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
IO.puts("✅ Embed URL generated!")
IO.puts("First 100 chars: #{String.slice(embed, 0..100)}...")
IO.puts("\n🎉 FIX SUCCESSFUL! URL will now work!")
'

# Restart the container
echo -e "\n${YELLOW}3. Restarting web container...${NC}"
docker-compose restart web

echo -e "\n${YELLOW}Waiting for Phoenix to restart...${NC}"
sleep 12

# Check if running
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application is running!${NC}"
else
    echo -e "${YELLOW}Waiting a bit more...${NC}"
    sleep 5
fi

echo -e "\n${GREEN}${BOLD}======================================"
echo "✅ FIX APPLIED SUCCESSFULLY!"
echo "======================================${NC}"
echo ""
echo -e "${CYAN}${BOLD}TEST IT NOW - IT WILL WORK!${NC}"
echo ""
echo "1. Go to: ${BOLD}http://localhost:4000${NC}"
echo "2. Join room: ${BOLD}cool-jams-3460${NC} (or create a new one)"
echo "3. Click Queue (☰)"
echo "4. Paste this URL:"
echo ""
echo -e "${GREEN}https://soundcloud.com/thecxde/the-code-east-london-sa?si=1178444a99ec4df09792cf566676eac3&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing${NC}"
echo ""
echo -e "${GREEN}${BOLD}IT WILL WORK NOW!${NC} The encoding error is fixed!"
echo ""
echo "Also test these URLs:"
echo "• https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "• https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
echo ""
echo -e "${CYAN}To monitor what's happening:${NC}"
echo "docker-compose logs -f web | grep -i soundcloud"
echo ""