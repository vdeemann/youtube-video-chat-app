@echo off
title SoundCloud Fix - YouTube Watch Party App

echo ================================================
echo    COMPREHENSIVE SOUNDCLOUD PLAYBACK FIX
echo ================================================
echo.
echo This will rebuild the app with all SoundCloud fixes
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo Stopping containers...
docker-compose down -v

echo.
echo Building with comprehensive fixes...
docker-compose build --no-cache web

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed!
    echo Please check Docker is running.
    pause
    exit /b 1
)

echo.
echo ================================================
echo          STARTING FIXED APPLICATION
echo ================================================
echo.
echo App will be at: http://localhost:4000
echo.
echo SoundCloud should now work properly!
echo - Tracks will auto-play when loaded
echo - Manual play button available as backup
echo - Check browser console (F12) for debug info
echo.
echo Press Ctrl+C to stop
echo.

docker-compose up

pause