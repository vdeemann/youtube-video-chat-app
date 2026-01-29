#!/bin/bash

# Quick Docker command helper
case "$1" in
    start)
        echo "🚀 Starting app..."
        docker-compose up -d
        sleep 5
        if curl -s http://localhost:4000 > /dev/null 2>&1; then
            echo "✅ App running at http://localhost:4000"
            open http://localhost:4000
        fi
        ;;
    stop)
        echo "🛑 Stopping app..."
        docker-compose down
        ;;
    restart)
        echo "🔄 Restarting app..."
        docker-compose restart
        ;;
    rebuild)
        echo "🔨 Rebuilding app..."
        docker-compose down
        docker-compose up --build -d
        ;;
    logs)
        echo "📊 Showing logs..."
        docker-compose logs -f
        ;;
    status)
        echo "📊 Status:"
        docker-compose ps
        ;;
    clean)
        echo "🧹 Cleaning everything..."
        docker-compose down -v --remove-orphans
        ;;
    *)
        echo "YouTube Watch Party - Docker Helper"
        echo ""
        echo "Usage: ./docker.sh [command]"
        echo ""
        echo "Commands:"
        echo "  start    - Start the app"
        echo "  stop     - Stop the app"
        echo "  restart  - Restart the app"
        echo "  rebuild  - Rebuild and start"
        echo "  logs     - Show logs"
        echo "  status   - Show container status"
        echo "  clean    - Remove everything"
        echo ""
        echo "Example: ./docker.sh start"
        ;;
esac
