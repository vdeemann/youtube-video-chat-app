@echo off
echo.
echo ================================================
echo  FIXING QUEUE AUTO-ADVANCEMENT - STEP BY STEP
echo ================================================
echo.
echo STEP 1: Rebuild JavaScript in Docker
echo ------------------------------------------------

docker-compose exec web mix assets.build

if errorlevel 1 (
    echo.
    echo ERROR: Could not connect to Docker container.
    echo Make sure Docker is running with: docker-compose up
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================
echo  SUCCESS! Assets Rebuilt
echo ================================================
echo.
echo STEP 2: YOU MUST DO THIS NOW:
echo ------------------------------------------------
echo.
echo  1. Go to your browser
echo  2. Press Ctrl + Shift + R (hard refresh)
echo     OR press Ctrl + F5
echo.
echo  3. Open browser console (press F12)
echo  4. You should see this log:
echo     "===================================================
echo      🎬 COMPREHENSIVE MEDIAPLAYER MOUNTED"
echo.
echo  5. If you see that, the fix is active!
echo.
echo STEP 3: Test It
echo ------------------------------------------------
echo.
echo  1. Add 2-3 videos to your queue
echo  2. Let the first video play to the end
echo  3. Watch it auto-advance to the next!
echo.
echo  In browser console you'll see:
echo    🎬 VIDEO ENDED
echo    📤 Pushing video_ended event to server...
echo.
echo  In Docker logs you'll see:
echo    [info] 🎬 VIDEO_ENDED EVENT
echo    [info] 🚀 HOST DETECTED - Triggering auto-advance
echo.
echo ================================================
echo  IMPORTANT: Did you hard refresh? (Ctrl+Shift+R)
echo ================================================
echo.
pause
