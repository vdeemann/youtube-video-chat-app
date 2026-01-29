#!/bin/bash

echo "🔧 SOUNDCLOUD ULTIMATE FIX WITH DEBUGGING"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${CYAN}${BOLD}STEP 1: Applying the fix with extensive logging${NC}"

# Ensure containers are running
docker-compose up -d
sleep 5

echo -e "\n${CYAN}Compiling the new code with debug logging...${NC}"
docker-compose exec web mix compile --force

echo -e "\n${CYAN}STEP 2: Testing URL parsing directly${NC}"
docker-compose exec web elixir -e '
require Logger

# Configure logger to show debug messages
Logger.configure(level: :debug)

defmodule TestParse do
  require Logger
  
  def test do
    url = "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83b41404370e4eafb0e1d85e24825601&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"
    
    IO.puts("\n=== TESTING SOUNDCLOUD URL ===")
    IO.puts("URL: #{String.slice(url, 0..80)}...")
    
    # Test basic detection
    contains_sc = String.contains?(String.downcase(url), "soundcloud.com")
    IO.puts("Contains soundcloud.com? #{contains_sc}")
    
    if contains_sc do
      # Test URI parsing
      uri = URI.parse(url)
      IO.puts("URI.host: #{inspect(uri.host)}")
      IO.puts("URI.path: #{inspect(uri.path)}")
      
      # Test clean URL generation
      path = uri.path || ""
      clean = "https://soundcloud.com#{path}"
      IO.puts("Clean URL: #{clean}")
      
      # Test path parsing
      parts = String.trim(path, "/") |> String.split("/")
      IO.puts("Path parts: #{inspect(parts)}")
      
      case parts do
        [artist, track | _] ->
          IO.puts("Artist: #{artist}")
          IO.puts("Track: #{track}")
          IO.puts("\n✅ URL SHOULD WORK!")
        _ ->
          IO.puts("\n⚠️  Could not parse path")
      end
      
      # Test embed URL generation
      encoded = URI.encode_www_form_component(clean)
      embed = "https://w.soundcloud.com/player/?url=#{encoded}&color=%23ff5500&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&show_teaser=false&visual=true"
      IO.puts("\nEmbed URL (first 100 chars):")
      IO.puts(String.slice(embed, 0..100) <> "...")
    else
      IO.puts("\n❌ NOT DETECTED AS SOUNDCLOUD")
    end
  end
end

TestParse.test()
'

echo -e "\n${CYAN}STEP 3: Restarting web container${NC}"
docker-compose restart web

echo -e "\n${YELLOW}Waiting for Phoenix to start...${NC}"
sleep 15

# Check if running
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application is running!${NC}"
else
    echo -e "${YELLOW}⚠️  Still starting, wait a moment...${NC}"
fi

echo -e "\n${CYAN}STEP 4: Monitoring logs${NC}"
echo "Starting log monitor (press Ctrl+C to stop)..."
echo -e "${YELLOW}Now go test the URL in your browser and watch the logs below:${NC}"
echo ""

echo -e "${GREEN}${BOLD}========================================"
echo "READY TO TEST!"
echo "========================================${NC}"
echo ""
echo "1. Go to: ${BOLD}http://localhost:4000/room/cool-jams-3460${NC}"
echo "2. ${BOLD}Open browser console${NC} (F12)"
echo "3. Click Queue (☰)"
echo "4. Paste this URL:"
echo ""
echo -e "${GREEN}https://soundcloud.com/thecxde/the-code-east-london-sa?si=83b41404370e4eafb0e1d85e24825601&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing${NC}"
echo ""
echo -e "${YELLOW}${BOLD}WATCH THE LOGS BELOW:${NC}"
echo "You should see detailed parsing information"
echo ""
echo -e "${CYAN}=== LIVE LOGS ===${NC}"

# Follow logs and highlight important parts
docker-compose logs -f web | grep --color=always -E "ADD VIDEO|PARSING|SOUNDCLOUD|ERROR|Success|Failed|soundcloud|media"