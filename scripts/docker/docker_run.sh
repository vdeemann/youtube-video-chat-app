#!/bin/bash

clear
echo "🐳 ================================================ 🐳"
echo "      DOCKER SETUP FOR YOUTUBE WATCH PARTY"
echo "🐳 ================================================ 🐳"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "📦 Docker is not installed."
    echo ""
    echo "Install Docker Desktop (choose one):"
    echo ""
    echo "1) Automatic install with Homebrew (recommended)"
    echo "2) Download manually from Docker website"
    echo "3) Exit"
    echo ""
    read -p "Choose (1/2/3): " choice
    
    case $choice in
        1)
            echo "Installing Docker Desktop..."
            brew install --cask docker
            echo "✅ Installed! Starting Docker..."
            open -a Docker
            echo ""
            echo "⏳ Docker is starting (takes 30-60 seconds)"
            echo "   Look for the whale icon 🐳 in your menu bar"
            echo ""
            echo "Once you see the whale icon, run:"
            echo "  ./docker_run.sh"
            ;;
        2)
            echo "Opening Docker website..."
            open "https://www.docker.com/products/docker-desktop/"
            echo ""
            echo "1. Download Docker Desktop"
            echo "2. Install it"
            echo "3. Start Docker Desktop"
            echo "4. Run ./docker_run.sh"
            ;;
        3)
            exit 0
            ;;
    esac
    exit 0
fi

# Docker is installed, check if running
if ! docker info &> /dev/null 2>&1; then
    echo "🔴 Docker is installed but not running"
    echo ""
    echo "Starting Docker Desktop..."
    open -a Docker
    
    echo "⏳ Waiting for Docker to start"
    count=0
    while ! docker info &> /dev/null 2>&1; do
        sleep 1
        count=$((count + 1))
        if [ $count -eq 10 ]; then
            echo "   (this can take 30-60 seconds on first start)"
        fi
        if [ $count -gt 90 ]; then
            echo ""
            echo "❌ Docker is taking too long. Please:"
            echo "1. Make sure Docker Desktop is running"
            echo "2. Look for the whale icon 🐳 in menu bar"
            echo "3. Run this script again"
            exit 1
        fi
        printf "."
    done
    echo " ✅"
fi

echo "✅ Docker is running!"
echo ""
echo "🚀 Starting YouTube Watch Party App..."
echo "================================================"
echo ""

# Clean up any old containers
docker-compose down 2>/dev/null

# Start with build
echo "Building containers (first time takes 2-3 minutes)..."
docker-compose up --build -d

# Wait for app to be ready
echo ""
echo "⏳ Waiting for app to start..."
sleep 5

# Check if app is accessible
max_attempts=30
attempt=0
while ! curl -s http://localhost:4000 > /dev/null 2>&1; do
    sleep 1
    attempt=$((attempt + 1))
    if [ $attempt -eq 10 ]; then
        echo "   Still starting (database setup)..."
    fi
    if [ $attempt -gt $max_attempts ]; then
        echo "❌ App failed to start. Check logs:"
        echo "   docker-compose logs"
        exit 1
    fi
done

echo ""
echo "🐳 ================================================ 🐳"
echo "   ✅ SUCCESS! YOUR APP IS RUNNING!"
echo "🐳 ================================================ 🐳"
echo ""
echo "📺 Opening browser to: http://localhost:4000"
open http://localhost:4000
echo ""
echo "📝 Useful commands:"
echo "   View logs:    docker-compose logs -f"
echo "   Stop app:     docker-compose down"
echo "   Restart:      docker-compose restart"
echo ""
echo "🎉 Enjoy your YouTube Watch Party!"
echo ""
echo "💡 Tip: Create a room and share the link with friends!"
echo ""

# Show logs
echo "📊 Showing app logs (press Ctrl+C to exit):"
echo "------------------------------------------------"
docker-compose logs -f
