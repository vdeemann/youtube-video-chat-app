#!/bin/bash

echo "================================================"
echo "🐳 DOCKER QUICK INSTALL & RUN"
echo "================================================"
echo ""

# Function to install Docker
install_docker() {
    echo "📦 Installing Docker Desktop via Homebrew..."
    brew install --cask docker
    
    echo ""
    echo "✅ Docker Desktop installed!"
    echo ""
    echo "🚀 Starting Docker Desktop for the first time..."
    open -a Docker
    
    echo ""
    echo "⏳ Docker Desktop is starting. This takes about 30-60 seconds."
    echo "   You'll see a whale icon in your menu bar when ready."
    echo ""
    echo "Once Docker is running (whale icon in menu bar), run:"
    echo "  ./docker_start.sh"
    echo ""
    echo "Or manually run:"
    echo "  docker-compose up"
    exit 0
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed."
    echo ""
    echo "Would you like to install Docker Desktop now? (y/n)"
    read -r response
    if [[ "$response" == "y" ]]; then
        install_docker
    else
        echo ""
        echo "Please install Docker Desktop manually:"
        echo "  https://www.docker.com/products/docker-desktop/"
        echo ""
        echo "Or via Homebrew:"
        echo "  brew install --cask docker"
        exit 1
    fi
fi

# Docker is installed, check if running
if ! docker info &> /dev/null; then
    echo "Docker is installed but not running."
    echo ""
    echo "Starting Docker Desktop..."
    open -a Docker
    
    echo "⏳ Waiting for Docker to start..."
    counter=0
    while ! docker info &> /dev/null; do
        sleep 2
        counter=$((counter + 2))
        if [ $counter -gt 60 ]; then
            echo ""
            echo "Docker is taking longer than expected to start."
            echo "Please make sure Docker Desktop is running (whale icon in menu bar)"
            echo "Then run: docker-compose up"
            exit 1
        fi
        printf "."
    done
    echo ""
    echo "✅ Docker is running!"
fi

# Docker is running, start the app
echo ""
echo "🚀 Starting your YouTube Watch Party app..."
echo ""

# Stop any existing containers
docker-compose down 2>/dev/null

# Start the app
docker-compose up --build

# Note: docker-compose up runs in foreground so you can see logs
# User can press Ctrl+C to stop
