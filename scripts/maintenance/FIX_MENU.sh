#!/bin/bash

clear
echo "======================================"
echo "   SOUNDCLOUD INTEGRATION FIX MENU"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Make all scripts executable
chmod +x *.sh 2>/dev/null

echo -e "${CYAN}${BOLD}Your Issue:${NC} SoundCloud URLs with tracking parameters are not being accepted"
echo -e "${CYAN}${BOLD}The Error:${NC} 'Invalid YouTube or SoundCloud URL'"
echo ""

echo -e "${GREEN}${BOLD}STEP 1: Test if SoundCloud embeds work at all${NC}"
echo "Open this in your browser: ${YELLOW}http://localhost:4000/direct_soundcloud_test.html${NC}"
echo "➡️  If you see players there, SoundCloud works and we just need to fix the parsing"
echo ""

echo -e "${GREEN}${BOLD}STEP 2: Choose a fix option:${NC}"
echo ""
echo "  ${CYAN}1)${NC} ${GREEN}Quick Test${NC} - Test if parsing works (10 seconds)"
echo "  ${CYAN}2)${NC} ${YELLOW}Apply Fix & Debug${NC} - Apply fix with logging (30 seconds)"
echo "  ${CYAN}3)${NC} ${RED}Complete Rebuild${NC} - Nuclear option, rebuild everything (5 minutes)"
echo "  ${CYAN}4)${NC} Exit"
echo ""

read -p "Enter your choice (1-4): " choice

case $choice in
  1)
    echo -e "\n${GREEN}${BOLD}Running Quick Test...${NC}\n"
    chmod +x quick_test.sh
    ./quick_test.sh
    echo -e "\n${CYAN}After seeing the test results above:${NC}"
    echo "• If it shows '🎉 URL PARSING WORKS!' - try the URL in your browser now"
    echo "• If it fails - choose option 2 or 3"
    ;;
    
  2)
    echo -e "\n${YELLOW}${BOLD}Applying Fix with Debug Logging...${NC}\n"
    chmod +x DEBUG_AND_FIX.sh
    ./DEBUG_AND_FIX.sh
    ;;
    
  3)
    echo -e "\n${RED}${BOLD}Starting Complete Rebuild...${NC}"
    echo -e "${RED}This will take about 5 minutes and rebuild everything from scratch.${NC}"
    read -p "Are you sure? (y/n): " confirm
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
      chmod +x NUCLEAR_REBUILD.sh
      ./NUCLEAR_REBUILD.sh
    else
      echo "Cancelled."
    fi
    ;;
    
  4)
    echo -e "\n${CYAN}Exiting...${NC}"
    exit 0
    ;;
    
  *)
    echo -e "\n${RED}Invalid choice. Running Quick Test by default...${NC}\n"
    chmod +x quick_test.sh
    ./quick_test.sh
    ;;
esac

echo -e "\n${GREEN}${BOLD}======================================"
echo "NEXT STEPS:"
echo "======================================${NC}"
echo ""
echo "1. ${BOLD}Test the URL in your browser:${NC}"
echo "   • Go to: http://localhost:4000"
echo "   • Join room: cool-jams-3460"
echo "   • Add this URL to queue:"
echo ""
echo -e "${GREEN}https://soundcloud.com/thecxde/the-code-east-london-sa?si=83b41404370e4eafb0e1d85e24825601&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing${NC}"
echo ""
echo "2. ${BOLD}If it still doesn't work:${NC}"
echo "   • Check: http://localhost:4000/direct_soundcloud_test.html"
echo "   • Run option 3 (Complete Rebuild)"
echo "   • Check Docker logs: docker-compose logs --tail=100 web"
echo ""
echo -e "${YELLOW}${BOLD}Remember to clear your browser cache (Ctrl+Shift+R) before testing!${NC}"
echo ""