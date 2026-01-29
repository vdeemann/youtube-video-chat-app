#!/bin/bash

# Docker-specific SoundCloud diagnostic

echo "🐳 Docker SoundCloud Integration Diagnostics"
echo "============================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${YELLOW}1. Checking Docker containers...${NC}"
if docker-compose ps | grep -q "web.*Up"; then
    echo -e "${GREEN}✅ Web container is running${NC}"
else
    echo -e "${RED}❌ Web container is not running${NC}"
    echo "   Run: docker-compose up -d"
    exit 1
fi

if docker-compose ps | grep -q "db.*Up"; then
    echo -e "${GREEN}✅ Database container is running${NC}"
else
    echo -e "${RED}❌ Database container is not running${NC}"
    echo "   Run: docker-compose up -d"
fi

echo -e "\n${YELLOW}2. Checking application status...${NC}"
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application is accessible at http://localhost:4000${NC}"
else
    echo -e "${RED}❌ Application is not accessible${NC}"
    echo "   Check logs: docker-compose logs web"
fi

echo -e "\n${YELLOW}3. Checking SoundCloud test page...${NC}"
if curl -s http://localhost:4000/test_soundcloud.html > /dev/null 2>&1; then
    echo -e "${GREEN}✅ SoundCloud test page is accessible${NC}"
else
    echo -e "${YELLOW}⚠️  SoundCloud test page not accessible${NC}"
fi

echo -e "\n${YELLOW}4. Checking JavaScript compilation...${NC}"
docker-compose exec web bash -c "
if [ -f 'priv/static/assets/app.js' ]; then
    echo '✅ JavaScript compiled'
    if grep -q 'MediaPlayer' priv/static/assets/app.js 2>/dev/null; then
        echo '✅ MediaPlayer hook found'
    else
        echo '⚠️  MediaPlayer hook not found - rebuild assets'
    fi
else
    echo '❌ JavaScript not compiled'
fi
" 2>/dev/null || echo -e "${YELLOW}⚠️  Could not check JavaScript compilation${NC}"

echo -e "\n${YELLOW}5. Recent container logs...${NC}"
echo -e "${BLUE}Last 10 lines from web container:${NC}"
docker-compose logs --tail=10 web 2>/dev/null | tail -10

echo -e "\n${YELLOW}6. Testing SoundCloud URL parsing...${NC}"
docker-compose exec web bash -c "
cat > /tmp/test_sc.exs << 'EOTEST'
url = \"https://soundcloud.com/odesza/say-my-name-feat-zyra\"
clean = url |> String.split(~r/[?#]/) |> List.first() |> String.trim()
encoded = URI.encode_www_form_component(clean)
IO.puts(\"✅ URL parses correctly\")
IO.puts(\"   Clean: #{clean}\")
IO.puts(\"   Encoded: #{String.slice(encoded, 0..50)}...\")
EOTEST
elixir /tmp/test_sc.exs 2>/dev/null
" || echo -e "${YELLOW}⚠️  Could not test URL parsing${NC}"

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}📋 Quick Test Instructions:${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "1. Open browser to: ${BLUE}http://localhost:4000/test_soundcloud.html${NC}"
echo "   All 4 test players should load and be playable"
echo ""
echo "2. Go to main app: ${BLUE}http://localhost:4000${NC}"
echo "   - Create or join a room"
echo "   - Click queue button (☰)"
echo "   - Add a SoundCloud URL:"
echo "     ${BLUE}https://soundcloud.com/odesza/say-my-name-feat-zyra${NC}"
echo ""
echo "3. Check browser console (F12) for:"
echo "   - \"MediaPlayer mounted - Type: soundcloud\""
echo "   - \"SoundCloud widget ready\""
echo ""
echo -e "${YELLOW}📝 Useful Docker commands:${NC}"
echo "   Logs:     docker-compose logs -f web"
echo "   Restart:  docker-compose restart web"
echo "   Rebuild:  ./docker_soundcloud_deploy.sh"
echo "   Shell:    docker-compose exec web bash"
echo ""