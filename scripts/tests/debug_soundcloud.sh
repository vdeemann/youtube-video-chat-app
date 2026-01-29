#!/bin/bash

echo "🔍 Debugging SoundCloud Integration"
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${YELLOW}Step 1: Checking if containers are running...${NC}"
docker-compose ps

echo -e "\n${YELLOW}Step 2: Testing URL parsing in Elixir...${NC}"
docker-compose exec web elixir -e '
defmodule TestParse do
  def test do
    url = "https://soundcloud.com/odesza/say-my-name-feat-zyra"
    IO.puts("Testing URL: #{url}")
    
    if String.contains?(url, "soundcloud.com") do
      IO.puts("✅ URL contains soundcloud.com")
      
      clean_url = url
      |> String.split(~r/[?#]/)
      |> List.first()
      |> String.trim()
      
      IO.puts("Clean URL: #{clean_url}")
      
      encoded = URI.encode_www_form_component(clean_url)
      embed_url = "https://w.soundcloud.com/player/?url=#{encoded}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
      
      IO.puts("Embed URL (first 100 chars): #{String.slice(embed_url, 0..100)}...")
    else
      IO.puts("❌ URL does not contain soundcloud.com")
    end
  end
end

TestParse.test()
'

echo -e "\n${YELLOW}Step 3: Checking if JavaScript hooks are compiled...${NC}"
docker-compose exec web bash -c '
if [ -f "priv/static/assets/app.js" ]; then
  echo "✅ app.js exists"
  if grep -q "MediaPlayer" priv/static/assets/app.js; then
    echo "✅ MediaPlayer hook found"
    echo "Checking for SoundCloud specifics..."
    grep -c "soundcloud" priv/static/assets/app.js && echo "✅ SoundCloud references found" || echo "❌ No SoundCloud references"
  else
    echo "❌ MediaPlayer hook NOT found"
  fi
else
  echo "❌ app.js does not exist"
fi
'

echo -e "\n${YELLOW}Step 4: Checking if test page exists...${NC}"
docker-compose exec web bash -c '
if [ -f "priv/static/test_soundcloud.html" ]; then
  echo "✅ test_soundcloud.html exists"
else
  echo "❌ test_soundcloud.html NOT found"
fi
'

echo -e "\n${YELLOW}Step 5: Checking recent error logs...${NC}"
echo -e "${BLUE}Last 20 lines mentioning errors:${NC}"
docker-compose logs --tail=100 web 2>&1 | grep -i "error\|exception\|failed" | tail -20

echo -e "\n${YELLOW}Step 6: Testing basic HTTP access...${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:4000 | grep -q "200"; then
  echo -e "${GREEN}✅ Main app responds with 200 OK${NC}"
else
  echo -e "${RED}❌ Main app not responding properly${NC}"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/test_soundcloud.html | grep -q "200\|404"; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/test_soundcloud.html)
  if [ "$STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Test page responds with 200 OK${NC}"
  else
    echo -e "${YELLOW}⚠️  Test page returns $STATUS${NC}"
  fi
fi

echo -e "\n${YELLOW}Step 7: Quick fix attempt...${NC}"
echo "Rebuilding assets..."
docker-compose exec web mix assets.build

echo -e "\n${GREEN}===================================${NC}"
echo -e "${GREEN}Diagnostic Complete!${NC}"
echo -e "${GREEN}===================================${NC}"
echo ""
echo -e "${YELLOW}🔧 Next Steps:${NC}"
echo "1. Open browser console (F12) and try adding a SoundCloud URL"
echo "2. Look for JavaScript errors in the console"
echo "3. Check Network tab to see if embed URL loads"
echo "4. Share any error messages you see"
echo ""
echo -e "${YELLOW}📝 Manual Test:${NC}"
echo "1. Go to http://localhost:4000"
echo "2. Create/join a room"
echo "3. Open browser console (F12)"
echo "4. Click queue button and add:"
echo "   https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "5. Check console for errors"
echo ""