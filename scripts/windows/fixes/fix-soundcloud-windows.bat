@echo off
echo ========================================
echo    FIXING SOUNDCLOUD PLAYBACK ISSUE
echo ========================================
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo Stopping existing containers...
docker-compose down

echo.
echo Rebuilding with SoundCloud fixes...
docker-compose build web

echo.
echo Starting the application...
docker-compose up

pause