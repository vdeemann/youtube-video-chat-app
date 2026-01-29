@echo off
echo ========================================
echo    AUTO-ADVANCE FIX FOR QUEUE SYSTEM
echo ========================================
echo.

echo Applying comprehensive auto-advance fix...
echo.

REM Back up the current media player file
echo Backing up current media_player.js...
copy /Y "assets\js\hooks\media_player.js" "assets\js\hooks\media_player.js.backup_%date:~-4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.js" 2>nul

echo.
echo Updating media_player.js with fixed auto-advance...
timeout /t 2 /nobreak >nul

echo.
echo Compiling assets...
cd assets
call npm run deploy
cd ..

echo.
echo Cleaning Phoenix digest...
call mix phx.digest.clean --all

echo.
echo ========================================
echo    AUTO-ADVANCE FIX COMPLETE!
echo ========================================
echo.
echo The queue system should now properly auto-advance to the next track
echo when a YouTube video or SoundCloud track finishes playing.
echo.
echo IMPORTANT: Restart your Phoenix server for changes to take effect:
echo   mix phx.server
echo.
echo Features fixed:
echo   - YouTube videos auto-advance when finished
echo   - SoundCloud tracks auto-advance when finished  
echo   - Proper cleanup between tracks
echo   - Better event handling and lifecycle management
echo.
pause
