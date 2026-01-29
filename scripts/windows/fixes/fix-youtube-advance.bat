@echo off
title Fix YouTube Auto-Advance - Watch Party App

echo ================================================
echo      FIXING YOUTUBE VIDEO AUTO-ADVANCE
echo ================================================
echo.
echo This fixes YouTube videos not advancing to next track
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo Restarting web container with fix...
docker-compose restart web

echo.
echo ================================================
echo              FIX APPLIED!
echo ================================================
echo.
echo YouTube videos should now properly:
echo  - Detect when they end
echo  - Auto-advance to next track
echo  - Remove from NOW PLAYING
echo.
echo Open browser console (F12) to see:
echo  [YouTube] State changes
echo  [YouTube] VIDEO ENDED messages
echo.
echo Test with short video:
echo https://www.youtube.com/watch?v=aqz-KE-bpKQ
echo.
pause