#!/bin/bash

# One-command Docker SoundCloud setup

echo "🚀 Setting up SoundCloud Integration for Docker..."
echo "=================================================="

# Make all scripts executable
chmod +x docker_soundcloud_deploy.sh 2>/dev/null
chmod +x docker_quick_restart.sh 2>/dev/null
chmod +x docker_soundcloud_check.sh 2>/dev/null
chmod +x docker_sc_logs.sh 2>/dev/null

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if containers are already running
if docker-compose ps | grep -q "web.*Up"; then
    echo -e "${YELLOW}Containers already running. Quick restart...${NC}"
    
    # Just rebuild assets and restart
    docker-compose exec web bash -c "cd assets && npm install && cd .. && mix assets.build" 2>/dev/null
    docker-compose restart web
    
    echo -e "${YELLOW}Waiting for restart...${NC}"
    sleep 8
else
    echo -e "${YELLOW}Starting fresh Docker build...${NC}"
    
    # Full rebuild
    docker-compose down
    docker-compose build web
    docker-compose up -d
    
    echo -e "${YELLOW}Waiting for services to start...${NC}"
    sleep 15
fi

# Wait for app to be ready
max_attempts=30
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

echo -e "\n${GREEN}=================================================${NC}"
echo -e "${GREEN}🎉 SoundCloud Integration Ready!${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo -e "${BLUE}📍 Test Pages:${NC}"
echo "   Main App:  http://localhost:4000"
echo "   Test Page: http://localhost:4000/test_soundcloud.html"
echo ""
echo -e "${BLUE}🎵 Test these SoundCloud URLs:${NC}"
echo "   • https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "   • https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
echo ""
echo -e "${BLUE}📝 How to test:${NC}"
echo "   1. Open http://localhost:4000"
echo "   2. Create/join a room"
echo "   3. Click queue button (☰)"
echo "   4. Paste a SoundCloud URL"
echo ""
echo -e "${YELLOW}🔧 Commands:${NC}"
echo "   Check status:  ./docker_soundcloud_check.sh"
echo "   View logs:     docker-compose logs -f web"
echo "   Quick restart: ./docker_quick_restart.sh"
echo ""