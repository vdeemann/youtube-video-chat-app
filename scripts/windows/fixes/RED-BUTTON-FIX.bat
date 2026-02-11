@echo off
color 0C
cls
echo.
echo  ============================================================
echo                    ULTIMATE YOUTUBE FIX
echo  ============================================================
echo.
echo  This fix adds a RED "NEXT TRACK" BUTTON that appears
echo  when YouTube videos end!
echo.
echo  No more stuck videos - just click the button!
echo.
echo  ============================================================
echo.
pause
echo.
echo  Starting fix...
echo.

cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

docker-compose down >nul 2>&1
docker-compose build web

if %ERRORLEVEL% NEQ 0 (
    color 04
    echo.
    echo  [ERROR] Build failed!
    pause
    exit /b 1
)

cls
color 0A
echo.
echo  ============================================================
echo                    FIX APPLIED SUCCESSFULLY!
echo  ============================================================
echo.
echo  WHAT'S NEW:
echo.
echo   [1] A RED BUTTON appears when videos end
echo   [2] Click it to go to next track
echo   [3] Type forceNextTrack() in console anytime
echo.
echo  ============================================================
echo.
echo  Starting app at http://localhost:4000
echo.

docker-compose up

pause