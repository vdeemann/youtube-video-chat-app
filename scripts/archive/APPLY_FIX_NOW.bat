@echo off
echo.
echo ========================================
echo  APPLYING QUEUE AUTO-ADVANCEMENT FIX
echo ========================================
echo.

cd /d "%~dp0"

echo Step 1: Checking for running Phoenix servers...
taskkill /F /IM beam.smp.exe 2>nul
taskkill /F /IM erl.exe 2>nul
echo Waiting for processes to stop...
timeout /t 3 /nobreak >nul

echo.
echo Step 2: Rebuilding JavaScript assets...
echo This will compile the new MediaPlayer hook...
echo.

call mix assets.build

if errorlevel 1 (
    echo.
    echo ========================================
    echo  ERROR: Build failed!
    echo ========================================
    echo.
    echo Please make sure:
    echo 1. Elixir is installed
    echo 2. Mix dependencies are installed
    echo.
    echo Try running: mix deps.get
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo  SUCCESS! Fix Applied
echo ========================================
echo.
echo The queue auto-advancement fix has been applied!
echo.
echo Would you like to start the server now? (Y/N)
set /p start_server=
if /i "%start_server%"=="Y" (
    echo.
    echo Starting Phoenix server...
    echo.
    echo ========================================
    echo  Server Running
    echo ========================================
    echo.
    echo Open: http://localhost:4000/rooms
    echo.
    echo Test steps:
    echo 1. Create or join a room
    echo 2. Add 2-3 videos/tracks to queue
    echo 3. Let first one play completely
    echo 4. Watch it auto-advance!
    echo.
    echo Press Ctrl+C to stop the server
    echo.
    timeout /t 3 /nobreak >nul
    start http://localhost:4000/rooms
    call mix phx.server
) else (
    echo.
    echo Fix applied! Run 'mix phx.server' when ready.
    echo.
    pause
)
