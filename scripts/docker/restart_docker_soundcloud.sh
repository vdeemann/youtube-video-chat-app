#!/bin/bash
set -e

echo "🔄 Restarting Docker containers with SoundCloud support..."
echo ""

# Stop existing containers
echo "📦 Stopping containers..."
docker-compose down

# Clean up any cached assets
echo "🧹 Cleaning cached assets..."
docker-compose run --rm web bash -c "rm -rf _build/dev/lib/youtube_video_chat_app_web && rm -rf priv/static/assets"

# Start containers fresh
echo "🚀 Starting containers with updated code..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 5

# Rebuild assets inside container
echo "🎨 Rebuilding assets..."
docker-compose exec web mix assets.build

# Show logs
echo ""
echo "✅ Docker containers restarted with SoundCloud support!"
echo ""
echo "📝 Follow the logs with: docker-compose logs -f web"
echo "🌐 Open http://localhost:4000 in your browser"
echo ""
echo "🎵 Test SoundCloud URLs:"
echo "   - https://soundcloud.com/platform/sama"
echo "   - Any public SoundCloud track URL"
echo ""
echo "📹 Test YouTube URL:"
echo "   - https://www.youtube.com/watch?v=dQw4w9WgXcQ"
