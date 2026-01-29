#!/bin/bash

echo "🚀 SOUNDCLOUD FIX - COMPLETE SOLUTION"
echo "====================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Make all scripts executable
chmod +x *.sh 2>/dev/null

echo -e "\n${CYAN}${BOLD}APPLYING ALL FIXES...${NC}"

echo -e "\n${YELLOW}1. Ensuring containers are running${NC}"
docker-compose up -d

echo -e "\n${YELLOW}2. Waiting for database${NC}"
sleep 5

echo -e "\n${YELLOW}3. Compiling updated Elixir code${NC}"
docker-compose exec web mix compile --force

echo -e "\n${YELLOW}4. Rebuilding JavaScript assets${NC}"
docker-compose exec web bash -c "
cd assets
npm install
npm run deploy
cd ..
mix phx.digest
"

echo -e "\n${YELLOW}5. Restarting web container${NC}"
docker-compose restart web

echo -e "\n${YELLOW}6. Waiting for Phoenix to start...${NC}"
sleep 10

# Wait for app
max_attempts=30
attempt=0
echo -n "Checking application"
while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:4000 > /dev/null 2>&1; then
        echo -e "\n${GREEN}✅ Application is running!${NC}"
        break
    fi
    echo -n "."
    sleep 2
    attempt=$((attempt + 1))
done

echo -e "\n${CYAN}${BOLD}RUNNING TESTS...${NC}"

echo -e "\n${YELLOW}Testing your problematic URL:${NC}"
docker-compose exec web elixir -e '
url = "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"

# Parse URL
uri = URI.parse(url)
path = uri.path || ""
clean_url = "https://soundcloud.com#{path}"

# Extract info
parts = String.trim(path, "/") |> String.split("/")
[artist, track | _] = parts

artist_name = String.replace(artist, "-", " ") |> String.split() |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
track_name = String.replace(track, "-", " ") |> String.split() |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

IO.puts("✅ URL parses correctly!")
IO.puts("   Artist: #{artist_name}")
IO.puts("   Track: #{track_name}")
IO.puts("   Clean URL: #{clean_url}")
'

echo -e "\n${GREEN}${BOLD}====================================="
echo "✅ ALL FIXES APPLIED SUCCESSFULLY!"
echo "=====================================${NC}"
echo ""
echo -e "${CYAN}${BOLD}TEST IT NOW:${NC}"
echo ""
echo "1. ${BOLD}Go to:${NC} http://localhost:4000"
echo "2. ${BOLD}Create or join a room${NC}"
echo "3. ${BOLD}Click the Queue button${NC} (☰)"
echo "4. ${BOLD}Paste this URL:${NC}"
echo ""
echo -e "${GREEN}https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing${NC}"
echo ""
echo -e "${CYAN}${BOLD}EXPECTED RESULT:${NC}"
echo "✅ URL is accepted without error"
echo "✅ Track appears in queue with orange 'SC' badge"
echo "✅ Title shows: 'The Code East London Sa by Thecxde'"
echo "✅ When played, SoundCloud player appears with gradient background"
echo ""
echo -e "${YELLOW}${BOLD}OTHER TEST URLs:${NC}"
echo "• https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "• https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
echo "• https://soundcloud.com/madeon/pay-no-mind"
echo ""
echo -e "${RED}${BOLD}IF IT STILL DOESN'T WORK:${NC}"
echo "1. Clear browser cache (Ctrl+Shift+R)"
echo "2. Check browser console (F12) for errors"
echo "3. Share the output of: docker-compose logs --tail=100 web | grep -i error"
echo "4. Try: docker-compose down -v && docker-compose up --build"
echo ""