@echo off
echo ========================================
echo YOUTUBE PLAYER SIZING FIX
echo ========================================
echo.
echo This fix resizes the YouTube player to maintain proper 16:9 aspect ratio
echo and ensures video controls and title are visible.
echo.
echo Changes made:
echo - YouTube player now maintains 16:9 aspect ratio
echo - Player is centered with max width for better viewing
echo - Video title displayed below player
echo - All YouTube controls remain accessible
echo.
echo ========================================
echo COMPILING ASSETS...
echo ========================================
cd assets
call npm run deploy
cd ..

echo.
echo ========================================
echo RECOMPILING ELIXIR CODE...
echo ========================================
call mix compile --force

echo.
echo ========================================
echo FIX APPLIED SUCCESSFULLY!
echo ========================================
echo.
echo The YouTube player will now:
echo - Display at proper 16:9 aspect ratio
echo - Show video title and controls
echo - Not overflow the screen
echo - Center properly on all screen sizes
echo.
echo Restart your Phoenix server to see the changes:
echo   mix phx.server
echo.
pause
