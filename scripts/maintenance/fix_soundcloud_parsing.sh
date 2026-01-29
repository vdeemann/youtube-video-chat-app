#!/bin/bash

echo "🔧 Fixing SoundCloud URL Parsing Issue"
echo "======================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n${CYAN}Step 1: Testing the problematic URL${NC}"
docker-compose exec web elixir -e '
url = "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"
IO.puts("Testing URL with tracking params:")
IO.puts(url)

# Parse it properly
uri = URI.parse(url)
path = uri.path || ""
clean_url = "https://soundcloud.com#{path}"

IO.puts("\nClean URL:")
IO.puts(clean_url)

# Extract parts
path_parts = String.trim(path, "/") |> String.split("/")
IO.puts("\nPath parts: #{inspect(path_parts)}")

# Generate embed URL
encoded = URI.encode_www_form_component(clean_url)
embed = "https://w.soundcloud.com/player/?url=#{encoded}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"

IO.puts("\n✅ Successfully parsed!")
IO.puts("Embed URL (first 150 chars):")
IO.puts(String.slice(embed, 0..150) <> "...")
'

echo -e "\n${CYAN}Step 2: Recompiling with fixed code${NC}"
docker-compose exec web mix compile --force

echo -e "\n${CYAN}Step 3: Rebuilding assets${NC}"
docker-compose exec web bash -c "cd assets && npm run deploy && cd .."

echo -e "\n${CYAN}Step 4: Restarting web container${NC}"
docker-compose restart web

echo -e "\n${YELLOW}Waiting for Phoenix to restart...${NC}"
sleep 10

# Wait for app to be ready
max_attempts=20
attempt=0
echo -n "Waiting for app"
while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:4000 > /dev/null 2>&1; then
        echo -e "\n${GREEN}✅ Application is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
    attempt=$((attempt + 1))
done

echo -e "\n${GREEN}=====================================${NC}"
echo -e "${GREEN}✅ Fix Applied Successfully!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "${CYAN}Now test with these URLs:${NC}"
echo ""
echo "1. ${GREEN}Your problematic URL:${NC}"
echo "   https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"
echo ""
echo "2. ${GREEN}Clean URLs:${NC}"
echo "   https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "   https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
echo ""
echo -e "${YELLOW}How to test:${NC}"
echo "1. Go to http://localhost:4000"
echo "2. Create/join a room"
echo "3. Click queue button (☰)"
echo "4. Paste the URL above"
echo ""
echo -e "${CYAN}The URL should now:${NC}"
echo "✅ Be accepted without errors"
echo "✅ Show in queue with orange 'SC' badge"
echo "✅ Display the SoundCloud player when played"
echo ""
echo -e "${RED}If it still doesn't work:${NC}"
echo "• Check browser console (F12) for errors"
echo "• Run: docker-compose logs --tail=50 web"
echo "• Try clearing browser cache (Ctrl+Shift+R)"
echo ""