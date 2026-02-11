@echo off
echo ================================================
echo       FIXING ROOM SERVER INITIALIZATION
echo ================================================
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo Restarting containers with fix...
docker-compose restart web

echo.
echo ================================================
echo                FIX APPLIED
echo ================================================
echo.
echo The room server initialization error has been fixed.
echo Try accessing your room again at http://localhost:4000
echo.
pause