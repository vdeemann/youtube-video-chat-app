#!/bin/bash

# Queue System Test Script
# This script helps verify the queue system is working correctly

echo "=================================="
echo "Queue System Test"
echo "=================================="
echo ""

# Check if server is running
echo "Step 1: Checking if server is running..."
if curl -s http://localhost:4000 > /dev/null 2>&1; then
    echo "✅ Server is running"
else
    echo "❌ Server is not running"
    echo "Start it with: mix phx.server"
    exit 1
fi

echo ""
echo "Step 2: Test Instructions"
echo "=================================="
echo ""
echo "To test the queue system:"
echo ""
echo "1. Open your browser to http://localhost:4000"
echo "2. Create or join a room"
echo "3. Add these test videos in order:"
echo ""
echo "   Video 1 (Short - 30s):"
echo "   https://www.youtube.com/watch?v=jNQXAC9IVRw"
echo ""
echo "   Video 2 (Shorter - 10s):"
echo "   https://www.youtube.com/watch?v=aqz-KE-bpKQ"
echo ""
echo "   Video 3 (Short - 20s):"
echo "   https://www.youtube.com/watch?v=C0DPdy98e4c"
echo ""
echo "4. Watch the server logs for:"
echo "   - 'ADDING TO QUEUE' messages"
echo "   - Queue contents listings"
echo "   - 'PLAY_NEXT CALLED' when videos end"
echo "   - Queue size decreasing"
echo ""
echo "5. Verify in the UI:"
echo "   ✅ First video plays immediately"
echo "   ✅ Videos 2 and 3 show in queue"
echo "   ✅ When video 1 ends, video 2 starts"
echo "   ✅ Queue shows only video 3"
echo "   ✅ When video 2 ends, video 3 starts"
echo "   ✅ Queue becomes empty"
echo "   ✅ When video 3 ends, player stops"
echo ""
echo "=================================="
echo ""

# Offer to tail the logs
read -p "Would you like to tail the server logs? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Tailing logs... (Press Ctrl+C to stop)"
    echo ""
    # Try to find the log file
    if [ -f "_build/dev/lib/youtube_video_chat_app/priv/log/dev.log" ]; then
        tail -f _build/dev/lib/youtube_video_chat_app/priv/log/dev.log
    else
        echo "Log file not found. Watch the terminal where you ran 'mix phx.server'"
    fi
fi
