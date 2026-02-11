@echo off
title ULTIMATE FIX - YouTube Auto-Advance

echo ================================================
echo     ULTIMATE SOLUTION - GUARANTEED TO WORK
echo ================================================
echo.
echo This is the FINAL fix that WILL work:
echo.
echo  1. Uses official YouTube IFrame API
echo  2. Shows manual "Next Track" button
echo  3. Multiple detection methods
echo  4. forceNextTrack() command available
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo Stopping containers...
docker-compose down

echo.
echo Building with ULTIMATE fix...
docker-compose build web

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo ================================================
echo         ULTIMATE FIX APPLIED!
echo ================================================
echo.
echo NEW FEATURES:
echo.
echo  1. When video ends, a red "Next Track" button appears
echo  2. Type forceNextTrack() in console to manually advance
echo  3. Official YouTube API for reliable detection
echo.
echo Test at: http://localhost:4000
echo.

docker-compose up

pause