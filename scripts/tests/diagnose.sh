#!/bin/bash

echo "🔍 Diagnostic Check for YouTube Watch Party App"
echo "==============================================="
echo ""

# Check files
echo "📁 Checking critical files..."
files=(
    "lib/youtube_video_chat_app_web/gettext.ex"
    "lib/youtube_video_chat_app/accounts.ex"
    "lib/youtube_video_chat_app_web/components/core_components.ex"
    "mix.exs"
    "docker-compose.yml"
    "Dockerfile.dev"
)

all_good=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file MISSING!"
        all_good=false
    fi
done

echo ""

# Check Docker
echo "🐳 Checking Docker..."
if docker info &> /dev/null; then
    echo "  ✅ Docker is running"
    
    # Check containers
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        echo "  ✅ Containers are running"
    else
        echo "  ⚠️  No containers running"
        echo "     Run: docker-compose up"
    fi
else
    echo "  ❌ Docker is not running"
    echo "     Start Docker Desktop first"
fi

echo ""

# Check port
echo "🔌 Checking port 4000..."
if lsof -i :4000 > /dev/null 2>&1; then
    if docker-compose ps 2>/dev/null | grep -q "4000"; then
        echo "  ✅ Port 4000 used by Docker"
    else
        echo "  ⚠️  Port 4000 used by another process"
        echo "     Run: lsof -i :4000"
    fi
else
    echo "  ✅ Port 4000 is free"
fi

echo ""

# Check app
echo "🌐 Checking application..."
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo "  ✅ Application is responding!"
    echo ""
    echo "==============================================="
    echo "🎉 Everything looks good!"
    echo "📺 Visit: http://localhost:4000"
else
    echo "  ❌ Application not responding"
    echo ""
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        echo "  Containers are running. Checking logs..."
        echo ""
        docker-compose logs --tail=10 web 2>/dev/null
    else
        echo "  No containers running."
        echo "  Run: ./rebuild_all.sh"
    fi
fi

echo ""
echo "==============================================="

if [ "$all_good" = true ]; then
    echo "✅ All files present"
    echo ""
    echo "Next steps:"
    echo "  1. Run: chmod +x rebuild_all.sh"
    echo "  2. Run: ./rebuild_all.sh"
    echo "  3. Wait for build to complete"
    echo "  4. Visit http://localhost:4000"
else
    echo "❌ Some files are missing"
    echo "Cannot proceed until all files are present"
fi
