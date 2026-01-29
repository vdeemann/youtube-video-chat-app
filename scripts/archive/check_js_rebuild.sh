#!/bin/bash

echo "🔍 Checking if JavaScript was rebuilt in Docker..."
echo ""

# Check if the updated media_player.js is in the container
echo "Looking for emoji logging in media_player.js..."
docker-compose exec web grep -q "🎬 MOUNTED" /app/assets/js/hooks/media_player.js

if [ $? -eq 0 ]; then
    echo "✅ JavaScript code IS updated in container"
    echo ""
    echo "The MediaPlayer hook should be working."
    echo "Open browser console (F12) and look for:"
    echo "  - [MediaPlayer] 🎬 MOUNTED"
    echo "  - [MediaPlayer] 👑 Is Host: true"
    echo ""
else
    echo "❌ JavaScript code NOT updated in container"
    echo ""
    echo "You need to rebuild Docker:"
    echo "  docker-compose down"
    echo "  docker-compose build --no-cache"
    echo "  docker-compose up"
    echo ""
fi

echo "Current approach:"
echo "  - Server timer fires at 185 seconds"
echo "  - This causes the pause you see"
echo ""
echo "To remove the pause, we need:"
echo "  1. JavaScript to detect actual video end"
echo "  2. Send 'video_ended' event immediately"
echo "  3. Server advances queue instantly"
echo ""
