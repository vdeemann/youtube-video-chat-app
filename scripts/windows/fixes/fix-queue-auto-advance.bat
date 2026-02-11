@echo off
echo ========================================
echo FIXING QUEUE AUTO-ADVANCEMENT
echo ========================================
echo.

echo Step 1: Rebuilding JavaScript assets...
cd assets
call npm run build
cd ..

echo.
echo Step 2: Recompiling Elixir...
call mix compile --force

echo.
echo Step 3: Starting server...
echo.
echo The queue system should now auto-advance properly!
echo.
echo TEST INSTRUCTIONS:
echo 1. Open http://localhost:4000/rooms in your browser
echo 2. Create or join a room
echo 3. Add 2-3 YouTube videos or SoundCloud tracks to the queue
echo 4. Let the first video/track play completely
echo 5. It should automatically advance to the next item
echo.
echo Watch the browser console (F12) for detailed logs
echo.
pause

call mix phx.server
