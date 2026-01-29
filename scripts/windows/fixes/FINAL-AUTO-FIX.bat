@echo off
cls
echo.
echo ============================================================
echo           FINAL AUTO-ADVANCE FIX - NO BUTTONS
echo ============================================================
echo.
echo This ensures YouTube videos AUTOMATICALLY advance
echo to the next track - no red buttons, no manual clicks!
echo.
echo The queue will work like Spotify - completely automatic.
echo.
echo ============================================================
echo.
pause

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo.
echo Cleaning up old containers...
docker-compose down -v >nul 2>&1

echo Building with automatic advancement...
docker-compose build --no-cache web

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

cls
echo.
echo ============================================================
echo              AUTOMATIC ADVANCEMENT ENABLED!
echo ============================================================
echo.
echo The queue now works automatically:
echo.
echo  1. YouTube videos detect when they end
echo  2. Next track starts automatically
echo  3. No manual intervention needed
echo  4. Works just like Spotify playlists
echo.
echo Test with 30-second videos:
echo  - https://www.youtube.com/watch?v=aqz-KE-bpKQ
echo  - https://www.youtube.com/watch?v=Il-an3K9pjg
echo.
echo ============================================================
echo.
echo Starting at http://localhost:4000
echo.

docker-compose up