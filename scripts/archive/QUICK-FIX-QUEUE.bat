@echo off
echo ========================================
echo QUICK FIX: Rebuilding Assets
echo ========================================
echo.

echo Stopping any running Phoenix server...
taskkill /F /IM beam.smp.exe 2>nul
taskkill /F /IM erl.exe 2>nul
timeout /t 2 /nobreak >nul

echo.
echo Rebuilding JavaScript and CSS...
call mix assets.build

echo.
echo ========================================
echo Assets rebuilt! Starting server...
echo ========================================
echo.
echo TEST STEPS:
echo 1. Go to http://localhost:4000/rooms
echo 2. Create/join a room
echo 3. Add 2+ videos/tracks to queue
echo 4. Watch the first one play to completion
echo 5. Should auto-advance to next item!
echo.
echo Press Ctrl+C to stop the server
echo.

call mix phx.server
