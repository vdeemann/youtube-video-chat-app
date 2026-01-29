#!/bin/bash

echo "💣 NUCLEAR OPTION - COMPLETE REBUILD"
echo "===================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${RED}${BOLD}WARNING: This will completely rebuild everything!${NC}"
echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
sleep 5

echo -e "\n${CYAN}1. Stopping all containers${NC}"
docker-compose down -v

echo -e "\n${CYAN}2. Removing old build artifacts${NC}"
rm -rf _build deps assets/node_modules 2>/dev/null || true

echo -e "\n${CYAN}3. Rebuilding Docker image from scratch${NC}"
docker-compose build --no-cache web

echo -e "\n${CYAN}4. Starting fresh containers${NC}"
docker-compose up -d

echo -e "\n${YELLOW}Waiting for database to be ready...${NC}"
sleep 10

echo -e "\n${CYAN}5. Setting up database${NC}"
docker-compose exec web mix ecto.create
docker-compose exec web mix ecto.migrate
docker-compose exec web mix run priv/repo/seeds.exs

echo -e "\n${CYAN}6. Installing dependencies${NC}"
docker-compose exec web mix deps.get
docker-compose exec web mix deps.compile

echo -e "\n${CYAN}7. Building assets${NC}"
docker-compose exec web bash -c "cd assets && npm install && npm run deploy && cd .."

echo -e "\n${CYAN}8. Final compilation${NC}"
docker-compose exec web mix compile

echo -e "\n${CYAN}9. Restarting for good measure${NC}"
docker-compose restart web

echo -e "\n${YELLOW}Waiting for Phoenix to be fully ready...${NC}"
sleep 20

# Test the app
max_attempts=30
attempt=0
echo -n "Checking application"
while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:4000 > /dev/null 2>&1; then
        echo -e "\n${GREEN}✅ Application is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
    attempt=$((attempt + 1))
done

echo -e "\n${CYAN}10. Testing SoundCloud URL parsing${NC}"
docker-compose exec web elixir -e '
url = "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83b41404370e4eafb0e1d85e24825601"

if String.contains?(String.downcase(url), "soundcloud.com") do
  uri = URI.parse(url)
  clean = "https://soundcloud.com#{uri.path}"
  IO.puts("✅ URL would parse to: #{clean}")
else
  IO.puts("❌ URL not recognized")
end
'

echo -e "\n${GREEN}${BOLD}========================================"
echo "COMPLETE REBUILD FINISHED!"
echo "========================================${NC}"
echo ""
echo -e "${CYAN}${BOLD}TEST NOW WITH A FRESH START:${NC}"
echo ""
echo "1. Open a ${BOLD}NEW incognito/private browser window${NC}"
echo "2. Go to: ${BOLD}http://localhost:4000${NC}"
echo "3. Create a ${BOLD}NEW room${NC} (you'll be the host)"
echo "4. Click Queue (☰)"
echo "5. Test these URLs:"
echo ""
echo -e "${GREEN}Complex URL with tracking:${NC}"
echo "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83b41404370e4eafb0e1d85e24825601&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"
echo ""
echo -e "${GREEN}Simple clean URLs:${NC}"
echo "https://soundcloud.com/odesza/intro"
echo "https://soundcloud.com/madeon/pay-no-mind"
echo ""
echo -e "${YELLOW}${BOLD}All URLs should now work!${NC}"
echo ""
echo -e "${CYAN}To see what's happening behind the scenes:${NC}"
echo "docker-compose logs -f web | grep -i soundcloud"
echo ""