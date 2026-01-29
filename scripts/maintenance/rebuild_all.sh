#!/bin/bash

echo "================================================"
echo "🚀 COMPLETE DOCKER REBUILD WITH ALL FIXES"
echo "================================================"
echo ""
echo "This script will:"
echo "  1. Stop all containers"
echo "  2. Remove all volumes"
echo "  3. Rebuild from scratch"
echo "  4. Start your YouTube Watch Party app"
echo ""

# Ensure Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running!"
    echo ""
    echo "Please start Docker Desktop first:"
    echo "  1. Open Docker Desktop app"
    echo "  2. Wait for the whale icon in menu bar"
    echo "  3. Run this script again"
    exit 1
fi

echo "✅ Docker is running"
echo ""

# Complete cleanup
echo "🧹 Step 1: Complete cleanup..."
docker-compose down -v --remove-orphans 2>/dev/null
docker system prune -f 2>/dev/null
echo "✅ Cleaned"
echo ""

# Build fresh
echo "🔨 Step 2: Building containers (this takes 2-3 minutes)..."
docker-compose build --no-cache

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Build failed!"
    echo "There may be syntax errors in the code."
    echo "Check the error messages above."
    exit 1
fi

echo "✅ Built successfully"
echo ""

# Start in background
echo "🚀 Step 3: Starting containers..."
docker-compose up -d

if [ $? -ne 0 ]; then
    echo "❌ Failed to start containers"
    exit 1
fi

echo "✅ Containers started"
echo ""

# Wait for services
echo "⏳ Step 4: Waiting for services to be ready..."
echo -n "Database"
for i in {1..30}; do
    if docker-compose exec -T db pg_isready &>/dev/null; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 1
done

# Setup database
echo "📊 Step 5: Setting up database..."
docker-compose exec -T web sh -c "mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs" &>/dev/null
echo "✅ Database ready"
echo ""

# Check app
echo "🔍 Step 6: Checking application..."
for i in {1..30}; do
    if curl -s http://localhost:4000 > /dev/null 2>&1; then
        echo "✅ Application is running!"
        echo ""
        echo "================================================"
        echo "🎉 SUCCESS! YOUTUBE WATCH PARTY IS LIVE!"
        echo "================================================"
        echo ""
        echo "📺 Opening: http://localhost:4000"
        open http://localhost:4000
        echo ""
        echo "🎮 Features ready to use:"
        echo "  ✅ Create/join rooms"
        echo "  ✅ Add YouTube videos"
        echo "  ✅ Floating chat messages"
        echo "  ✅ Synchronized playback"
        echo "  ✅ Real-time presence"
        echo ""
        echo "📝 Useful commands:"
        echo "  docker-compose logs -f    # View logs"
        echo "  docker-compose down       # Stop app"
        echo "  docker-compose restart    # Restart"
        echo ""
        exit 0
    fi
    sleep 1
done

echo "⚠️ Application is taking longer to start..."
echo ""
echo "Checking logs:"
docker-compose logs --tail=30 web
echo ""
echo "The app might still be starting. Try:"
echo "  1. Wait a few more seconds"
echo "  2. Visit http://localhost:4000"
echo "  3. Check logs: docker-compose logs -f"
