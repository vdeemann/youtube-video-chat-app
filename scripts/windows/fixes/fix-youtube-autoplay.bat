@echo off
echo ========================================
echo YOUTUBE AUTO-PLAY FIX
echo ========================================
echo.
echo This fix enables automatic playback when YouTube videos are added to the queue.
echo.
echo Changes made:
echo - YouTube embed URLs now use autoplay=1 instead of autoplay=0
echo - JavaScript ensures autoplay parameter is set when loading videos
echo - Both initial load and queue advancement will auto-play
echo.
echo ========================================
echo COMPILING ASSETS...
echo ========================================
cd assets
call npm run deploy
cd ..

echo.
echo ========================================
echo RECOMPILING ELIXIR CODE...
echo ========================================
call mix deps.get
call mix compile --force

echo.
echo ========================================
echo FIX APPLIED SUCCESSFULLY!
echo ========================================
echo.
echo To test the fix:
echo 1. Start the server: mix phx.server
echo 2. Create or join a room
echo 3. Add a YouTube video to the queue
echo 4. The video should start playing automatically
echo.
echo Note: Some browsers may require user interaction (click) on the page
echo before allowing autoplay with sound. If videos don't auto-play:
echo - Try clicking anywhere on the page first
echo - Check browser autoplay settings
echo - Consider using mute=1 for guaranteed autoplay (but no sound)
echo.
pause
