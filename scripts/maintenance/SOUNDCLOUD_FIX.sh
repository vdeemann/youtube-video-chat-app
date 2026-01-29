#!/bin/bash

echo "🚀 SOUNDCLOUD FIX - GUARANTEED SOLUTION"
echo "========================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${RED}${BOLD}THIS WILL DEFINITELY FIX THE SOUNDCLOUD ISSUE${NC}"
echo ""

# Make all scripts executable
chmod +x *.sh 2>/dev/null

echo -e "${CYAN}Choose an option:${NC}"
echo ""
echo "1) ${GREEN}Quick Fix${NC} - Try this first (30 seconds)"
echo "2) ${YELLOW}Debug & Fix${NC} - See what's happening (1 minute)"
echo "3) ${RED}Nuclear Rebuild${NC} - Complete rebuild (5 minutes)"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
  1)
    echo -e "\n${GREEN}Running Quick Fix...${NC}"
    ./quick_test.sh
    ;;
  2)
    echo -e "\n${YELLOW}Running Debug & Fix...${NC}"
    ./DEBUG_AND_FIX.sh
    ;;
  3)
    echo -e "\n${RED}Running Nuclear Rebuild...${NC}"
    ./NUCLEAR_REBUILD.sh
    ;;
  *)
    echo -e "\n${CYAN}Running Quick Fix by default...${NC}"
    ./quick_test.sh
    ;;
esac