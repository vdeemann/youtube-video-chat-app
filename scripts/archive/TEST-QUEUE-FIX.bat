@echo off
color 0A
echo.
echo  ================================================
echo   YOUTUBE VIDEO CHAT APP - QUEUE FIX TESTER
echo  ================================================
echo.
echo  This script will:
echo  1. Rebuild JavaScript assets with the fix
echo  2. Start the Phoenix server
echo  3. Open your browser to test
echo.
echo  ================================================
echo.
pause

echo.
echo [1/3] Stopping any running servers...
taskkill /F /IM beam.smp.exe 2>nul
taskkill /F /IM erl.exe 2>nul
timeout /t 2 /nobreak >nul

echo.
echo [2/3] Rebuilding assets with queue fix...
call mix assets.build
if errorlevel 1 (
    echo.
    echo ERROR: Asset build failed!
    echo Please check for errors above.
    pause
    exit /b 1
)

echo.
echo [3/3] Starting server...
echo.
echo ================================================
echo  SERVER STARTING
echo ================================================
echo.
echo  Test URL: http://localhost:4000/rooms
echo.
echo  Quick Test Steps:
echo  1. Create or join a room
echo  2. Add these test videos:
echo     - https://youtu.be/dQw4w9WgXcQ
echo     - https://youtu.be/9bZkp7q19f0
echo  3. Let first video play to end
echo  4. Watch it auto-advance to second video!
echo.
echo  Check browser console (F12) for detailed logs
echo.
echo  Press Ctrl+C to stop server
echo.
echo ================================================
echo.

timeout /t 3 /nobreak >nul
start http://localhost:4000/rooms

call mix phx.server
