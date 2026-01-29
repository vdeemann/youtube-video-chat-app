@echo off
chcp 65001 >nul
echo.
echo ========================================
echo  QUEUE AUTO-ADVANCEMENT FIX
echo ========================================
echo.
echo This will rebuild JavaScript and start the server.
echo.
pause

cd /d "%~dp0"

echo.
echo [1/3] Stopping any running servers...
taskkill /F /IM beam.smp.exe 2>nul
taskkill /F /IM erl.exe 2>nul
timeout /t 2 /nobreak >nul

echo.
echo [2/3] Rebuilding JavaScript assets...
echo.

call mix assets.build

if errorlevel 1 (
    echo.
    echo ========================================
    echo  BUILD ERROR
    echo ========================================
    echo.
    echo The build failed. This is likely due to:
    echo 1. Missing Visual Studio Build Tools
    echo 2. Missing nmake
    echo.
    echo QUICK FIX:
    echo Run this command instead:
    echo   mix phx.server
    echo.
    echo The JavaScript fix is already in place,
    echo it just needs to be compiled by the
    echo Phoenix server.
    echo.
    pause
    echo.
    echo Starting server anyway...
    timeout /t 2 /nobreak >nul
)

echo.
echo [3/3] Starting Phoenix server...
echo.
echo ========================================
echo  SERVER STARTING
echo ========================================
echo.
echo Opening browser at: http://localhost:4000/rooms
echo.
echo TEST STEPS:
echo 1. Create or join a room
echo 2. Add 2-3 videos to queue
echo 3. Let first video play completely
echo 4. Watch it auto-advance!
echo.
echo Press Ctrl+C to stop the server
echo ========================================
echo.

timeout /t 2 /nobreak >nul
start http://localhost:4000/rooms

call mix phx.server
