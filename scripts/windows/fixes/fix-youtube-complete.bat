@echo off
echo ========================================
echo COMPLETE YOUTUBE PLAYER FIX
echo ========================================
echo.
echo This applies both fixes:
echo 1. AUTO-PLAY: Videos start automatically when added
echo 2. SIZING: Player maintains proper 16:9 aspect ratio
echo.
echo ========================================
echo APPLYING FIXES...
echo ========================================
echo.

echo [1/3] Compiling frontend assets...
cd assets
call npm run deploy >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Failed to compile assets
    echo Try running: cd assets ^&^& npm install
    pause
    exit /b 1
)
echo      Done!
cd ..

echo.
echo [2/3] Getting dependencies...
call mix deps.get >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)
echo      Done!

echo.
echo [3/3] Recompiling Elixir code...
call mix compile --force >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Failed to compile
    pause
    exit /b 1
)
echo      Done!

echo.
echo ========================================
echo ALL FIXES APPLIED SUCCESSFULLY!
echo ========================================
echo.
echo YouTube Player Improvements:
echo.
echo [AUTO-PLAY]
echo   - Videos start automatically when added to queue
echo   - Auto-advance to next track when video ends
echo   - Works after first page interaction
echo.
echo [SIZING]
echo   - Proper 16:9 aspect ratio maintained
echo   - All controls and title visible
echo   - Responsive and centered display
echo.
echo ========================================
echo.
echo Next steps:
echo   1. Start the server: mix phx.server
echo   2. Create/join a room
echo   3. Add YouTube videos to test
echo.
echo Note: Click anywhere on the page first if videos
echo don't auto-play (browser security requirement)
echo.
pause
