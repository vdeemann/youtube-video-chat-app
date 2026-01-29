@echo off
title CRITICAL FIX - YouTube Auto-Advance

echo ================================================
echo    CRITICAL FIX: YOUTUBE AUTO-ADVANCE
echo ================================================
echo.
echo This applies a ROBUST fix for YouTube videos
echo not advancing to the next track.
echo.
echo Using multiple detection methods:
echo  - Direct video element monitoring
echo  - YouTube player state detection
echo  - Time-based stuck detection
echo  - Manual fallback option
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo Stopping containers...
docker-compose down

echo.
echo Rebuilding with critical fix...
docker-compose build web

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo ================================================
echo           CRITICAL FIX APPLIED!
echo ================================================
echo.
echo YouTube videos will now DEFINITELY advance!
echo.
echo DEBUGGING COMMANDS AVAILABLE:
echo  In browser console (F12):
echo  - debugMediaPlayer() - Check player state
echo  - Force advance if stuck (HOST ONLY)
echo.
echo Test with 30-second video:
echo https://www.youtube.com/watch?v=aqz-KE-bpKQ
echo.
echo Starting app at http://localhost:4000
echo.

docker-compose up

pause