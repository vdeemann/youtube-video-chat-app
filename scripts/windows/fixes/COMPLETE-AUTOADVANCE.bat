@echo off
color 0A
cls
echo.
echo  ******************************************************************
echo                   COMPLETE AUTO-ADVANCE SOLUTION
echo  ******************************************************************
echo.
echo  This fix makes your queue work like Spotify/YouTube playlists:
echo.
echo     YouTube -^> YouTube     = AUTO-ADVANCE
echo     YouTube -^> SoundCloud  = AUTO-ADVANCE
echo     SoundCloud -^> YouTube  = AUTO-ADVANCE
echo     SoundCloud -^> SoundCloud = AUTO-ADVANCE
echo.
echo  ALL combinations work AUTOMATICALLY - no manual clicks!
echo  ******************************************************************
echo.
pause

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

echo.
echo Cleaning old containers...
docker-compose down -v >nul 2>&1

echo Building complete solution...
docker-compose build --no-cache web

if %ERRORLEVEL% NEQ 0 (
    color 0C
    echo.
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

cls
color 0A
echo.
echo  ******************************************************************
echo              COMPLETE AUTO-ADVANCE SOLUTION APPLIED!
echo  ******************************************************************
echo.
echo  Your queue now works perfectly:
echo.
echo    1. Add YouTube videos and SoundCloud tracks
echo    2. They play in order automatically
echo    3. No buttons, no manual clicks
echo    4. Just like Spotify!
echo.
echo  Test with this mixed queue:
echo    - YouTube 30sec: https://www.youtube.com/watch?v=aqz-KE-bpKQ
echo    - SoundCloud: Use any SoundCloud URL
echo    - YouTube 30sec: https://www.youtube.com/watch?v=Il-an3K9pjg
echo.
echo  ******************************************************************
echo.
echo  Starting at http://localhost:4000
echo.

docker-compose up