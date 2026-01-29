@echo off
cls
echo.
echo ==============================================================
echo     YOUTUBE AUTO-ADVANCE TO ANY TRACK (YouTube/SoundCloud)
echo ==============================================================
echo.
echo This fix ensures YouTube videos AUTOMATICALLY advance to:
echo   - Next YouTube video in queue
echo   - Next SoundCloud track in queue
echo   - Any media type - completely automatic!
echo.
echo NO manual intervention needed - works like Spotify!
echo ==============================================================
echo.
pause

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo.
echo Stopping old containers...
docker-compose down

echo.
echo Building with complete auto-advance...
docker-compose build web

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

cls
echo.
echo ==============================================================
echo           AUTO-ADVANCE ENABLED FOR ALL MEDIA TYPES!
echo ==============================================================
echo.
echo YouTube videos will now automatically advance to:
echo   [Y] Next YouTube video
echo   [Y] Next SoundCloud track
echo   [Y] Mixed queue (YouTube -^> SoundCloud -^> YouTube)
echo.
echo Test sequence:
echo   1. YouTube (30s): https://www.youtube.com/watch?v=aqz-KE-bpKQ
echo   2. SoundCloud: https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew
echo   3. YouTube (30s): https://www.youtube.com/watch?v=Il-an3K9pjg
echo.
echo Watch them play in sequence AUTOMATICALLY!
echo ==============================================================
echo.
echo Starting at http://localhost:4000
echo.

docker-compose up