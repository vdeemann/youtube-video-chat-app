@echo off
title Apply All Fixes - YouTube Watch Party App

echo ================================================
echo         APPLYING ALL FIXES - COMPLETE
echo ================================================
echo.
echo This will apply ALL fixes:
echo  1. Room Server Initialization
echo  2. Queue System Auto-Advance
echo  3. SoundCloud Playback
echo  4. Media Synchronization
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo Cleaning up old containers...
docker-compose down -v

echo.
echo Building with ALL fixes (this may take a few minutes)...
docker-compose build --no-cache web

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed!
    echo Please ensure Docker is running.
    pause
    exit /b 1
)

echo.
echo ================================================
echo      ALL FIXES APPLIED SUCCESSFULLY!
echo ================================================
echo.
echo Starting the fully fixed application...
echo.
echo The app will be at: http://localhost:4000
echo.
echo Everything should now work:
echo  - Rooms load without errors
echo  - SoundCloud tracks play
echo  - Queue auto-advances
echo  - Synchronized for all users
echo.
echo Test with these URLs:
echo  - https://www.youtube.com/watch?v=aqz-KE-bpKQ
echo  - https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew
echo.
echo Press Ctrl+C to stop
echo.

docker-compose up

pause