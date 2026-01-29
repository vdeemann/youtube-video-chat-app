@echo off
title AUTO-ADVANCE FIX - No Manual Intervention

echo ================================================
echo       AUTOMATIC QUEUE ADVANCEMENT FIX
echo ================================================
echo.
echo This fix ensures YouTube videos automatically
echo advance to the next track without any buttons
echo or manual intervention.
echo.
echo Features:
echo  - Polls video progress every 500ms
echo  - Detects when video reaches end
echo  - Automatically triggers next track
echo  - No red buttons needed!
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo Stopping containers...
docker-compose down

echo.
echo Building with auto-advance fix...
docker-compose build web

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo ================================================
echo        AUTO-ADVANCE FIX APPLIED!
echo ================================================
echo.
echo The queue will now advance automatically when
echo YouTube videos end. No manual intervention needed!
echo.
echo Console will show:
echo  [YouTube] Progress: 25.0/30.0 (5.0s left)
echo  [YouTube] Video ended (polling detection)
echo  === VIDEO_ENDED EVENT ===
echo.
echo Starting app at http://localhost:4000
echo.

docker-compose up

pause