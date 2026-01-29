#!/bin/bash

echo "🔍 Checking Docker Container JavaScript..."
echo ""

# Check if the new code is in the container
echo "1. Checking if simplified media_player.js is in container..."
docker-compose exec web cat /app/assets/js/hooks/media_player.js | head -20

echo ""
echo "2. Checking for the mount message..."
docker-compose exec web grep -c "MEDIA PLAYER MOUNTED" /app/assets/js/hooks/media_player.js || echo "NOT FOUND"

echo ""
echo "3. Listing JavaScript build artifacts..."
docker-compose exec web ls -la /app/priv/static/assets/app*.js 2>/dev/null || echo "Build artifacts not found"

echo ""
echo "================================"
echo "DIAGNOSIS:"
echo "================================"

if docker-compose exec web grep -q "MEDIA PLAYER MOUNTED" /app/assets/js/hooks/media_player.js 2>/dev/null; then
    echo "✅ Source code IS updated"
    echo ""
    echo "But JavaScript might not be compiled yet."
    echo "The issue: Docker might be caching the old built files."
    echo ""
    echo "SOLUTION:"
    echo "  1. docker-compose down -v"
    echo "  2. docker-compose build --no-cache"
    echo "  3. docker-compose up"
    echo ""
else
    echo "❌ Source code NOT updated"
    echo ""
    echo "The container is using old JavaScript!"
    echo ""
    echo "SOLUTION:"
    echo "  Rebuild from scratch:"
    echo "  docker-compose down"
    echo "  docker-compose build --no-cache"
    echo "  docker-compose up"
fi
