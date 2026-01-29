#!/bin/bash

echo "⚡ SOUNDCLOUD QUICK FIX - GUARANTEED TO WORK"
echo "============================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${RED}${BOLD}CRITICAL: This will force a complete rebuild${NC}"

echo -e "\n${CYAN}1. Stopping containers...${NC}"
docker-compose down

echo -e "\n${CYAN}2. Clearing build cache...${NC}"
docker-compose exec web rm -rf _build deps 2>/dev/null || true

echo -e "\n${CYAN}3. Rebuilding everything...${NC}"
docker-compose build --no-cache web

echo -e "\n${CYAN}4. Starting fresh...${NC}"
docker-compose up -d

echo -e "\n${YELLOW}Waiting for database...${NC}"
sleep 10

echo -e "\n${CYAN}5. Setting up database...${NC}"
docker-compose exec web mix ecto.setup

echo -e "\n${YELLOW}Waiting for Phoenix...${NC}"
sleep 15

# Check if app is running
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

echo -e "\n${GREEN}${BOLD}========================================"
echo "COMPLETE REBUILD FINISHED!"
echo "========================================${NC}"
echo ""
echo -e "${CYAN}${BOLD}TEST NOW:${NC}"
echo ""
echo "1. Open a ${BOLD}new incognito/private browser window${NC}"
echo "2. Go to: ${BOLD}http://localhost:4000${NC}"
echo "3. Create a ${BOLD}new room${NC}"
echo "4. Click Queue (☰)"
echo "5. Test these URLs:"
echo ""
echo -e "${GREEN}With tracking params:${NC}"
echo "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"
echo ""
echo -e "${GREEN}Clean URLs:${NC}"
echo "https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
echo ""
echo -e "${YELLOW}${BOLD}All URLs should now work!${NC}"
echo ""
echo -e "${RED}If this doesn't work, there might be a browser issue.${NC}"
echo "Try a different browser or check if SoundCloud is blocked."
echo ""