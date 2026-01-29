#!/bin/bash

echo "🔧 Fixing compilation error and restarting Docker..."
echo ""

# Stop existing containers
docker-compose down

# Rebuild and start
echo "🔨 Rebuilding containers..."
docker-compose up --build -d

# Wait for app
echo "⏳ Waiting for app to start..."
sleep 10

# Check if running
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo ""
    echo "✅ SUCCESS! App is running!"
    echo "📺 Visit: http://localhost:4000"
    open http://localhost:4000
else
    echo "Checking logs..."
    docker-compose logs --tail=50
fi
