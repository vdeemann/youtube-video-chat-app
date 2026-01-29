#!/bin/bash
# Apply instant queue advancement fix

echo "============================================"
echo "🚀 APPLYING INSTANT QUEUE ADVANCEMENT FIX"
echo "============================================"
echo ""
echo "This removes the backup timer system that was"
echo "causing 180+ second delays between tracks."
echo ""
echo "Now videos will advance INSTANTLY when they end!"
echo ""

# Check if running in Docker
if [ -f "docker-compose.yml" ] && docker compose ps | grep -q "web"; then
    echo "📦 Detected Docker environment"
    echo "Restarting web container..."
    docker compose restart web
    echo ""
    echo "✅ Changes applied!"
    echo ""
    echo "Test it:"
    echo "1. Add 2-3 videos to the queue"
    echo "2. Watch the first one end"
    echo "3. Next video should start in ~1-2 seconds"
else
    echo "💻 Detected local environment"
    echo ""
    echo "Please restart your server:"
    echo "  1. Stop with Ctrl+C"
    echo "  2. Run: mix phx.server"
fi

echo ""
echo "============================================"
echo "📖 See INSTANT_QUEUE_ADVANCEMENT.md for details"
echo "============================================"
