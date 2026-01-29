#!/bin/bash

# Quick restart for Docker with asset rebuild

echo "🔄 Quick Restart with SoundCloud Integration"
echo "============================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\n${YELLOW}Rebuilding assets and restarting...${NC}"

# Rebuild assets inside the container
echo "📦 Rebuilding JavaScript assets..."
docker-compose exec web bash -c "cd assets && npm install && cd .. && mix assets.build"

# Restart the web container to pick up Elixir changes
echo "🔄 Restarting web container..."
docker-compose restart web

echo -e "\n${YELLOW}Waiting for Phoenix to restart...${NC}"
sleep 8

# Check if app is running
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application restarted successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Application may still be starting...${NC}"
    echo "Check logs with: docker-compose logs -f web"
fi

echo -e "\n${GREEN}Ready to test!${NC}"
echo "🌐 http://localhost:4000"
echo "🧪 http://localhost:4000/test_soundcloud.html"