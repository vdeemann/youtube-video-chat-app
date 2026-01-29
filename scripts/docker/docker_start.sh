#!/bin/bash

echo "================================================"
echo "🐳 DOCKER SETUP FOR YOUTUBE WATCH PARTY APP"
echo "================================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "📦 Docker not installed. Installing Docker Desktop..."
    echo ""
    echo "Option 1: Download manually:"
    echo "  https://www.docker.com/products/docker-desktop/"
    echo ""
    echo "Option 2: Install via Homebrew:"
    echo "  brew install --cask docker"
    echo ""
    echo "After installing, run this script again."
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "🔴 Docker is installed but not running."
    echo ""
    echo "Starting Docker Desktop..."
    
    # Try to start Docker Desktop
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open -a Docker
        echo "⏳ Waiting for Docker to start (this may take 30 seconds)..."
        
        # Wait for Docker to start
        counter=0
        while ! docker info &> /dev/null; do
            sleep 2
            counter=$((counter + 2))
            if [ $counter -gt 60 ]; then
                echo "❌ Docker is taking too long to start."
                echo "Please start Docker Desktop manually and run this script again."
                exit 1
            fi
            echo -n "."
        done
        echo ""
        echo "✅ Docker is now running!"
    else
        echo "Please start Docker Desktop manually and run this script again."
        exit 1
    fi
else
    echo "✅ Docker is running!"
fi

echo ""
echo "================================================"
echo "🚀 STARTING YOUR APP WITH DOCKER"
echo "================================================"
echo ""

# Stop any existing containers
echo "🧹 Cleaning up any existing containers..."
docker-compose down 2>/dev/null || true

# Build and start
echo "🔨 Building and starting your app..."
echo "This will take 2-3 minutes the first time..."
echo ""

docker-compose up --build -d

if [ $? -eq 0 ]; then
    echo ""
    echo "⏳ Waiting for app to be ready..."
    sleep 5
    
    # Check if app is running
    if curl -s http://localhost:4000 > /dev/null; then
        echo ""
        echo "================================================"
        echo "🎉 SUCCESS! Your app is running!"
        echo "================================================"
        echo ""
        echo "📺 Visit: http://localhost:4000"
        echo ""
        echo "📝 Useful Docker commands:"
        echo "  View logs:        docker-compose logs -f"
        echo "  Stop app:         docker-compose down"
        echo "  Restart app:      docker-compose restart"
        echo "  Rebuild app:      docker-compose up --build"
        echo ""
        echo "💡 The app is running in the background."
        echo "   Your terminal is free to use!"
        echo ""
        
        # Open browser
        echo "Opening browser..."
        open http://localhost:4000
    else
        echo "⚠️  App is still starting. Check logs with:"
        echo "docker-compose logs -f"
    fi
else
    echo "❌ Failed to start. Check the error messages above."
    echo ""
    echo "Common fixes:"
    echo "1. Make sure port 4000 is free: lsof -i :4000"
    echo "2. Check Docker Desktop is running"
    echo "3. Try: docker-compose down && docker-compose up --build"
fi
