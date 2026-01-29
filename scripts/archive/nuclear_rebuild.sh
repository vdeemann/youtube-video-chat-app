#!/bin/bash

echo "🔥 NUCLEAR REBUILD - Forcing complete JavaScript recompilation"
echo "================================================================"
echo ""

echo "Step 1: Stopping all containers..."
docker-compose down -v

echo ""
echo "Step 2: Removing ALL Docker build cache..."
docker builder prune -af

echo ""
echo "Step 3: Removing old node_modules and build artifacts..."
docker-compose run --rm web rm -rf /app/assets/node_modules
docker-compose run --rm web rm -rf /app/priv/static/assets
docker-compose run --rm web rm -rf /app/_build

echo ""
echo "Step 4: Building from absolute scratch (no cache)..."
docker-compose build --no-cache --pull

echo ""
echo "Step 5: Starting up..."
docker-compose up -d

echo ""
echo "Step 6: Waiting for server to be ready..."
sleep 10

echo ""
echo "✅ DONE! Now:"
echo "  1. Open http://localhost:4000 in your browser"
echo "  2. Hard refresh: Ctrl+Shift+R (or Cmd+Shift+R on Mac)"
echo "  3. Open Console (F12)"
echo "  4. Look for this message:"
echo ""
echo "     ===================================================
"
echo "     🎬 ULTIMATE MEDIAPLAYER MOUNTED"
echo "     ===================================================
"
echo ""
echo "  5. Add a video and watch it auto-advance INSTANTLY when it ends!"
echo ""
echo "If you still don't see the message, run:"
echo "  docker-compose logs -f web | grep -i 'ultimate\\|mounted\\|ended'"
