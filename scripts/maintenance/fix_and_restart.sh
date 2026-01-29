#!/bin/bash

echo "================================================"
echo "🔧 FIXING COMPILATION ERROR & RESTARTING"
echo "================================================"
echo ""

echo "✅ Fixed syntax error in accounts.ex"
echo ""

# Clean and rebuild
echo "🧹 Cleaning old containers..."
docker-compose down --volumes --remove-orphans

echo ""
echo "🔨 Building fresh containers..."
echo "This will take 2-3 minutes..."
echo ""

# Build in foreground so we can see any errors
docker-compose build

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Build failed. There might be more syntax errors."
    echo "Check the error messages above."
    exit 1
fi

echo ""
echo "🚀 Starting application..."
docker-compose up -d

# Give it time to start
echo "⏳ Waiting for application to be ready..."
sleep 5

# Check database and migrations
echo "📊 Running database setup..."
docker-compose exec -T web mix ecto.create 2>/dev/null
docker-compose exec -T web mix ecto.migrate

# Wait a bit more
sleep 5

# Check if app is running
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo ""
    echo "================================================"
    echo "🎉 SUCCESS! YOUR APP IS RUNNING!"
    echo "================================================"
    echo ""
    echo "📺 Opening browser: http://localhost:4000"
    open http://localhost:4000
    echo ""
    echo "📝 Commands:"
    echo "  View logs:  docker-compose logs -f"
    echo "  Stop:       docker-compose down"
    echo "  Restart:    docker-compose restart"
    echo ""
    echo "💬 Create a room and start watching YouTube!"
else
    echo ""
    echo "⚠️ App might still be starting. Checking logs..."
    echo ""
    docker-compose logs --tail=30
    echo ""
    echo "If you see errors above, the app may need more time."
    echo "Try: docker-compose logs -f"
fi
