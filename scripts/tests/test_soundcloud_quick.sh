#!/bin/bash

# Quick test script for SoundCloud integration

echo "🎵 SoundCloud Integration Quick Test"
echo "===================================="

# Make scripts executable
chmod +x diagnose_soundcloud.sh 2>/dev/null
chmod +x start.sh 2>/dev/null

# Check if server is running
if ! lsof -i :4000 > /dev/null 2>&1; then
    echo "📌 Starting Phoenix server..."
    ./start.sh &
    SERVER_PID=$!
    
    echo "⏳ Waiting for server to start..."
    sleep 5
    
    # Wait for server to be ready
    while ! curl -s http://localhost:4000 > /dev/null 2>&1; do
        sleep 1
    done
fi

echo "✅ Server is running!"
echo ""
echo "🧪 Test Pages Available:"
echo "===================================="
echo "1️⃣  Standalone SoundCloud Test:"
echo "   http://localhost:4000/test_soundcloud.html"
echo ""
echo "2️⃣  Main Application:"
echo "   http://localhost:4000"
echo ""
echo "3️⃣  Demo Room (if exists):"
echo "   http://localhost:4000/room/demo-room"
echo ""
echo "📋 Test SoundCloud URLs to try:"
echo "===================================="
echo "• https://soundcloud.com/odesza/say-my-name-feat-zyra"
echo "• https://soundcloud.com/rickastley/never-gonna-give-you-up-4"
echo "• https://soundcloud.com/flume/flume-holdin-on"
echo ""
echo "🔍 Debugging:"
echo "===================================="
echo "• Press F12 in browser for console"
echo "• Run ./diagnose_soundcloud.sh for diagnostics"
echo "• Check SOUNDCLOUD_TESTING.md for full guide"
echo ""
echo "Press Ctrl+C to stop the server"

# Keep script running if we started the server
if [ ! -z "$SERVER_PID" ]; then
    wait $SERVER_PID
fi