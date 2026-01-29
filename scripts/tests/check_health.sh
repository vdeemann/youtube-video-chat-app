#!/bin/bash

echo "🔍 Checking Docker Health..."
echo "=============================="
echo ""

# Check Docker
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running"
    echo "   Start Docker Desktop first"
    exit 1
fi
echo "✅ Docker is running"

# Check containers
if docker-compose ps | grep -q "Up"; then
    echo "✅ Containers are running"
else
    echo "❌ Containers are not running"
    echo "   Run: docker-compose up"
    exit 1
fi

# Check web app
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo "✅ Web app is accessible"
else
    echo "⚠️  Web app not responding"
    echo "   Checking logs..."
    docker-compose logs --tail=20 web
fi

# Check database
if docker-compose exec -T db pg_isready > /dev/null 2>&1; then
    echo "✅ Database is ready"
else
    echo "⚠️  Database not ready"
fi

echo ""
echo "=============================="
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo "🎉 Everything looks good!"
    echo "📺 Visit: http://localhost:4000"
else
    echo "🔧 Need to fix issues above"
fi
