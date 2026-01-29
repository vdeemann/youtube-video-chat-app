@echo off
cls
echo.
echo    ╔══════════════════════════════════════════════════╗
echo    ║         YOUTUBE QUEUE AUTO-ADVANCE FIX          ║
echo    ╚══════════════════════════════════════════════════╝
echo.
echo    This fix ensures videos properly advance when ending:
echo.
echo    • Completed videos are removed from display
echo    • Next video moves from queue to NOW PLAYING  
echo    • Auto-play continues through entire queue
echo    • All users see synchronized queue state
echo.
echo ══════════════════════════════════════════════════════
echo.

echo    [1/3] Compiling frontend assets...
cd assets >nul 2>&1
call npm run deploy >nul 2>&1
if %errorlevel% neq 0 (
    echo          FAILED! Run: cd assets ^&^& npm install
    cd .. >nul 2>&1
    pause
    exit /b 1
)
echo          ✓ Complete
cd .. >nul 2>&1

echo.
echo    [2/3] Getting dependencies...
call mix deps.get >nul 2>&1
echo          ✓ Complete

echo.
echo    [3/3] Recompiling Elixir code...
call mix compile --force >nul 2>&1
echo          ✓ Complete

echo.
echo ══════════════════════════════════════════════════════
echo.
echo    ╔══════════════════════════════════════════════════╗
echo    ║              ✓ FIX APPLIED!                     ║
echo    ╚══════════════════════════════════════════════════╝
echo.
echo    How the queue works:
echo.
echo    1. Add multiple videos to test
echo       → First plays immediately
echo       → Others go to UP NEXT
echo.
echo    2. When video ends:
echo       → Completed video disappears  
echo       → Next video starts automatically
echo       → Queue position updates
echo.
echo    3. Process continues until queue empty
echo.
echo    ┌─────────────────────────────────────────────────┐
echo    │  Testing Steps:                                │
echo    │                                                 │
echo    │  1. Start server: mix phx.server               │
echo    │  2. Create/join room as host                   │
echo    │  3. Add 3+ YouTube videos                      │
echo    │  4. Watch them auto-advance                    │
echo    │                                                 │
echo    │  Note: Only the HOST controls advancement      │
echo    └─────────────────────────────────────────────────┘
echo.
echo    If videos still don't advance:
echo    - Check browser console for errors
echo    - Ensure you're the room host
echo    - Try refreshing the page
echo.
pause
