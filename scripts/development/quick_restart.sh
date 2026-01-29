#!/bin/bash
set -e

echo "🔄 Quick restart for Docker containers..."
echo ""

# Just restart the web container to pick up code changes
echo "📦 Restarting web container..."
docker-compose restart web

# Wait a moment
sleep 3

# Show status
echo ""
echo "✅ Container restarted!"
echo ""
docker-compose ps
echo ""
echo "📝 Check logs: docker-compose logs -f web"
echo "🌐 Open http://localhost:4000"
echo ""
echo "🎵 Test with SoundCloud: https://soundcloud.com/platform/sama"
