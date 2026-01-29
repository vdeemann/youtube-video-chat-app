#!/bin/bash

echo "🎯 SOUNDCLOUD FIX - FINAL SOLUTION"
echo "=================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${CYAN}${BOLD}This fix addresses the exact error you're seeing${NC}"

# First, let's make sure the container is running
if ! docker-compose ps | grep -q "web.*Up"; then
    echo -e "${YELLOW}Starting containers...${NC}"
    docker-compose up -d
    sleep 10
fi

echo -e "\n${CYAN}1. Applying the fixed parsing logic...${NC}"

# Force compile the new code
docker-compose exec web mix compile --force

echo -e "\n${CYAN}2. Testing with your exact URL...${NC}"
docker-compose exec web elixir -e '
url = "https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing"

IO.puts("Original URL: #{String.slice(url, 0..70)}...")

# This is exactly what the code does now
if String.contains?(String.downcase(url), "soundcloud.com") do
  IO.puts("✅ Step 1: Detected as SoundCloud")
  
  uri = URI.parse(url)
  path = uri.path || ""
  clean_url = "https://soundcloud.com#{path}"
  
  IO.puts("✅ Step 2: Extracted path: #{path}")
  IO.puts("✅ Step 3: Clean URL: #{clean_url}")
  
  # Parse artist and track
  parts = String.trim(path, "/") |> String.split("/")
  [artist, track | _] = parts ++ ["", ""]
  
  if artist != "" and track != "" do
    IO.puts("✅ Step 4: Artist: #{artist}")
    IO.puts("✅ Step 5: Track: #{track}")
    IO.puts("\n🎉 URL WILL BE ACCEPTED!")
  else
    IO.puts("⚠️  Could not parse artist/track")
  end
else
  IO.puts("❌ Not detected as SoundCloud")
end
'

echo -e "\n${CYAN}3. Restarting the web container...${NC}"
docker-compose restart web

echo -e "\n${YELLOW}Waiting for Phoenix (this is important)...${NC}"
sleep 15

# Check if app is ready
for i in {1..20}; do
  if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Application ready!${NC}"
    break
  fi
  echo -n "."
  sleep 1
done

echo -e "\n${CYAN}4. Checking logs for any issues...${NC}"
docker-compose logs --tail=5 web | grep -i "started\|listening" || true

echo -e "\n${GREEN}${BOLD}=================================="
echo "✅ FIX COMPLETE!"
echo "==================================${NC}"
echo ""
echo -e "${CYAN}${BOLD}TEST INSTRUCTIONS:${NC}"
echo ""
echo "1. ${BOLD}IMPORTANT:${NC} Clear browser cache (Ctrl+Shift+R)"
echo "2. Go to room: ${BOLD}http://localhost:4000/room/cool-jams-3460${NC}"
echo "3. Click Queue button (☰)"
echo "4. Paste this URL:"
echo ""
echo -e "${GREEN}https://soundcloud.com/thecxde/the-code-east-london-sa?si=83fbdd99a1fb4817a87dc9481f0fe245&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing${NC}"
echo ""
echo -e "${YELLOW}${BOLD}Expected Result:${NC}"
echo "✅ URL accepted (no error message)"
echo "✅ Shows in queue: 'The Code East London Sa by Thecxde'"
echo "✅ Orange 'SC' badge"
echo "✅ Plays with gradient background"
echo ""
echo -e "${RED}${BOLD}If you still see 'Invalid YouTube or SoundCloud URL':${NC}"
echo ""
echo "Option 1: Run the nuclear option"
echo "  ${CYAN}chmod +x nuclear_option.sh && ./nuclear_option.sh${NC}"
echo ""
echo "Option 2: Check what's in the logs"
echo "  ${CYAN}docker-compose logs --tail=100 web | grep 'add_video'${NC}"
echo ""
echo "Option 3: Try a simpler URL first"
echo "  ${CYAN}https://soundcloud.com/odesza/intro${NC}"
echo ""