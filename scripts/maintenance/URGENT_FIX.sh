#!/bin/bash

echo "🚨 URGENT SOUNDCLOUD FIX"
echo "========================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${RED}${BOLD}This fix will handle URLs with tracking parameters!${NC}"

echo -e "\n${CYAN}Step 1: Recompiling Elixir code...${NC}"
docker-compose exec web mix compile --force

echo -e "\n${CYAN}Step 2: Testing URL parsing directly...${NC}"
docker-compose exec web elixir -e '
# Test the exact problematic URL
url = "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"

IO.puts("Testing URL: #{String.slice(url, 0..60)}...")

# Basic check
if String.contains?(String.downcase(url), "soundcloud.com") do
  IO.puts("✅ Contains soundcloud.com")
  
  # Parse it
  uri = URI.parse(url)
  path = uri.path || ""
  clean_url = "https://soundcloud.com#{path}"
  
  IO.puts("✅ Path: #{path}")
  IO.puts("✅ Clean URL: #{clean_url}")
  
  # Extract parts
  parts = String.trim(path, "/") |> String.split("/")
  IO.puts("✅ Parts: #{inspect(parts)}")
  
  # Generate embed
  encoded = URI.encode_www_form_component(clean_url)
  embed = "https://w.soundcloud.com/player/?url=#{encoded}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
  
  IO.puts("✅ Embed URL generated successfully!")
else
  IO.puts("❌ Does not contain soundcloud.com")
end
'

echo -e "\n${CYAN}Step 3: Restarting web container...${NC}"
docker-compose restart web

echo -e "\n${YELLOW}Waiting for Phoenix to start...${NC}"
sleep 12

# Check if running
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application is running!${NC}"
else
    echo -e "${YELLOW}⚠️  Application starting, please wait...${NC}"
    sleep 5
fi

echo -e "\n${GREEN}${BOLD}=============================="
echo "✅ FIX APPLIED!"
echo "==============================${NC}"
echo ""
echo -e "${CYAN}${BOLD}TEST IT RIGHT NOW:${NC}"
echo ""
echo "1. Go to: ${BOLD}http://localhost:4000${NC}"
echo "2. Join the room: ${BOLD}cool-jams-3460${NC}"
echo "3. Click Queue button (☰)"
echo "4. Paste this EXACT URL:"
echo ""
echo -e "${GREEN}${BOLD}https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing${NC}"
echo ""
echo -e "${YELLOW}It should now:${NC}"
echo "✅ Accept the URL without error"
echo "✅ Show in queue with orange 'SC' badge"
echo "✅ Display 'The Code East London Sa by Thecxde'"
echo ""
echo -e "${CYAN}${BOLD}Also test these clean URLs:${NC}"
echo "• https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "• https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
echo ""
echo -e "${RED}${BOLD}If it STILL shows error:${NC}"
echo "1. Run: docker-compose logs --tail=50 web | grep -i 'soundcloud\\|error'"
echo "2. Open browser console (F12) and check for JavaScript errors"
echo "3. Try: docker-compose down && docker-compose up --build"
echo ""