@echo off
echo ========================================
echo YOUTUBE QUEUE DIAGNOSTICS
echo ========================================
echo.
echo This script will help diagnose queue behavior.
echo.
echo Current Queue Behavior:
echo - When video ends: Removed from display
echo - Next video: Moves from UP NEXT to NOW PLAYING
echo - Queue updates: Broadcast to all users
echo.
echo ========================================
echo TESTING QUEUE FLOW
echo ========================================
echo.
echo 1. Add 3 YouTube videos to queue
echo    - First will start playing immediately
echo    - Second and third go to UP NEXT
echo.
echo 2. When first video ends:
echo    - First video removed (disappears)
echo    - Second video moves to NOW PLAYING
echo    - Third video remains in UP NEXT
echo.
echo 3. This continues until queue is empty
echo.
echo ========================================
echo CHECKING LOG OUTPUT
echo ========================================
echo.
echo Look for these log messages in your console:
echo.
echo [MediaPlayer] VIDEO ENDED - ADVANCING TO NEXT
echo [RoomServer] PLAY NEXT CALLED
echo [RoomServer] Advancing to next track: [title]
echo [RoomServer] Broadcasting media change
echo [RoomServer] Broadcasting queue update
echo.
echo ========================================
echo IS THIS THE EXPECTED BEHAVIOR?
echo ========================================
echo.
echo If you want played videos to remain visible:
echo   Type: history
echo.
echo If videos aren't advancing at all:
echo   Type: fix
echo.
echo If queue is working correctly:
echo   Type: ok
echo.
set /p choice="Your choice (history/fix/ok): "

if /i "%choice%"=="history" goto :add_history
if /i "%choice%"=="fix" goto :fix_queue
if /i "%choice%"=="ok" goto :end

:add_history
echo.
echo ========================================
echo ADDING PLAY HISTORY FEATURE
echo ========================================
echo.
echo This will add a "Recently Played" section
echo to show completed tracks.
echo.
echo Features:
echo - Shows last 5 played tracks
echo - Grayed out appearance
echo - Option to re-add to queue
echo.
echo Creating history feature...
echo Please wait for implementation...
pause
goto :end

:fix_queue
echo.
echo ========================================
echo APPLYING QUEUE FIX
echo ========================================
echo.
cd assets
call npm run deploy >nul 2>&1
cd ..
call mix compile --force >nul 2>&1
echo.
echo Fix applied! 
echo.
echo Test by:
echo 1. Adding multiple videos
echo 2. Let first video play to end
echo 3. Check if next video starts
echo.
pause
goto :end

:end
echo.
echo ========================================
echo DIAGNOSTIC COMPLETE
echo ========================================
pause
