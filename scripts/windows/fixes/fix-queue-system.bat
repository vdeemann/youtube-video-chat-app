@echo off
title Queue System Fix - YouTube Watch Party App

echo ================================================
echo       FIXING QUEUE SYSTEM AND AUTO-ADVANCE
echo ================================================
echo.
echo This will fix the queue/playlist system:
echo - Separate "Now Playing" from "Up Next"
echo - Auto-advance to next track
echo - Synchronized across all users
echo - Better visual indicators
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo Stopping containers...
docker-compose down

echo.
echo Building with queue fixes...
docker-compose build web

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed!
    echo Please check Docker is running.
    pause
    exit /b 1
)

echo.
echo ================================================
echo           STARTING FIXED APPLICATION
echo ================================================
echo.
echo App will be at: http://localhost:4000
echo.
echo Queue Features:
echo - Now Playing: Shows current track
echo - Up Next: Shows queued tracks
echo - Auto-advance when track ends
echo - Synchronized for all users
echo.
echo Press Ctrl+C to stop
echo.

docker-compose up

pause