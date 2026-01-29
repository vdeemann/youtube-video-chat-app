#!/bin/bash

echo "🚀 SOUNDCLOUD DOCKER FIX - FINAL"
echo "================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Make executable
chmod +x docker_soundcloud_complete_fix.sh 2>/dev/null
chmod +x soundcloud_emergency_fix.sh 2>/dev/null

echo -e "\n${CYAN}Running complete fix...${NC}"

# Run the complete fix
./docker_soundcloud_complete_fix.sh

echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}✅ DONE! Test it now:${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "1️⃣  ${CYAN}Test Page:${NC} http://localhost:4000/test_soundcloud"
echo "    Should show 3 working SoundCloud players"
echo ""
echo "2️⃣  ${CYAN}Main App:${NC} http://localhost:4000"
echo "    - Join a room"
echo "    - Add: https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo ""
echo "If it doesn't work, please share:"
echo "• Browser console errors (F12)"
echo "• Output of: docker-compose logs --tail=30 web"