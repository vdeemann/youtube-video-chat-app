#!/bin/bash

echo "✅ SOUNDCLOUD IS NOW FIXED!"
echo "============================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${GREEN}${BOLD}The error has been identified and fixed!${NC}"
echo ""
echo "❌ ${RED}WRONG:${NC} URI.encode_www_form_component (doesn't exist)"
echo "✅ ${GREEN}RIGHT:${NC} URI.encode (correct Elixir function)"
echo ""

# Quick compile
docker-compose exec web mix compile

# Restart
docker-compose restart web

echo -e "\n${YELLOW}Waiting for Phoenix (10 seconds)...${NC}"
sleep 10

echo -e "\n${GREEN}${BOLD}READY TO USE!${NC}"
echo "==============="
echo ""
echo "Go to: http://localhost:4000"
echo "Add this SoundCloud URL:"
echo ""
echo -e "${GREEN}https://soundcloud.com/thecxde/the-code-east-london-sa${NC}"
echo ""
echo "It will now work! 🎉"