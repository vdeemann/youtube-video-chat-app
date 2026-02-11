@echo off
echo ========================================
echo YOUTUBE PLAYER FULL-SIZE LAYOUT FIX
echo ========================================
echo.
echo This fix maximizes the YouTube player to use all available
echo screen space between the header and chat input area.
echo.
echo Changes made:
echo - Player fills space from header to chat input
echo - YouTube controls visible above chat area
echo - Maintains 16:9 aspect ratio
echo - Maximizes viewing area
echo.
echo ========================================
echo COMPILING ASSETS...
echo ========================================
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
echo ========================================
echo RECOMPILING ELIXIR CODE...
echo ========================================
call mix compile --force >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Failed to compile
    pause
    exit /b 1
)
echo      Done!

echo.
echo ========================================
echo FIX APPLIED SUCCESSFULLY!
echo ========================================
echo.
echo The YouTube player now:
echo - Uses maximum available screen space
echo - Shows controls just above chat input
echo - Maintains proper aspect ratio
echo - Provides immersive viewing experience
echo.
echo Layout details:
echo - Top: Aligned with header (76px)
echo - Bottom: Aligned with chat input (100px)
echo - Width: Auto-calculated for 16:9 ratio
echo.
echo Restart your Phoenix server to see changes:
echo   mix phx.server
echo.
pause
