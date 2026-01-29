#!/bin/bash

# Docker-specific script to rebuild and restart with SoundCloud integration

echo "🎵 Deploying SoundCloud Integration with Docker"
echo "==============================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "\n${YELLOW}1. Stopping existing containers...${NC}"
docker-compose down

echo -e "\n${YELLOW}2. Rebuilding with new SoundCloud code...${NC}"
docker-compose build --no-cache web

echo -e "\n${YELLOW}3. Starting containers...${NC}"
docker-compose up -d

echo -e "\n${YELLOW}4. Waiting for Phoenix to start...${NC}"
sleep 10

# Wait for the app to be ready
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s http://localhost:4000 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Application is ready!${NC}"
        break
    fi
    echo -n "."
    sleep 2
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "\n${YELLOW}⚠️  Application took longer than expected to start${NC}"
    echo "Check logs with: docker-compose logs -f web"
fi

echo -e "\n${GREEN}===============================================${NC}"
echo -e "${GREEN}🎉 SoundCloud Integration Deployed!${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo "📍 Test URLs:"
echo "   Main App: http://localhost:4000"
echo "   Test Page: http://localhost:4000/test_soundcloud.html"
echo ""
echo "🎵 SoundCloud URLs to test:"
echo "   • https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "   • https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
echo ""
echo "📝 Commands:"
echo "   View logs: docker-compose logs -f web"
echo "   Stop: docker-compose down"
echo "   Restart: docker-compose restart web"
echo ""