@echo off
cls
echo.
echo    ╔══════════════════════════════════════════════════╗
echo    ║     YOUTUBE PLAYER - COMPLETE FIX PACKAGE       ║
echo    ╚══════════════════════════════════════════════════╝
echo.
echo    This applies ALL YouTube player improvements:
echo.
echo    1. [AUTO-PLAY FIX]
echo       • Videos start automatically when added
echo       • Auto-advance when video ends
echo.
echo    2. [FULL-SIZE LAYOUT]
echo       • Maximized player size
echo       • Fills space between header and chat
echo       • YouTube controls visible above chat input
echo.
echo    3. [ASPECT RATIO]
echo       • Maintains proper 16:9 ratio
echo       • Prevents distortion
echo       • Responsive sizing
echo.
echo ══════════════════════════════════════════════════════
echo.
echo Press any key to apply all fixes...
pause >nul

cls
echo.
echo    ╔══════════════════════════════════════════════════╗
echo    ║              APPLYING FIXES                     ║
echo    ╚══════════════════════════════════════════════════╝
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
if %errorlevel% neq 0 (
    echo          FAILED!
    pause
    exit /b 1
)
echo          ✓ Complete

echo.
echo    [3/3] Recompiling Elixir code...
call mix compile --force >nul 2>&1
if %errorlevel% neq 0 (
    echo          FAILED!
    pause
    exit /b 1
)
echo          ✓ Complete

echo.
echo ══════════════════════════════════════════════════════
echo.
echo    ╔══════════════════════════════════════════════════╗
echo    ║           ✓ ALL FIXES APPLIED!                  ║
echo    ╚══════════════════════════════════════════════════╝
echo.
echo    YouTube Player Enhancements Active:
echo.
echo    • Auto-play enabled (after first click)
echo    • Full-size immersive layout
echo    • Controls aligned above chat input
echo    • Proper 16:9 aspect ratio
echo    • Auto-advance to next video
echo.
echo    ┌─────────────────────────────────────────────────┐
echo    │  Next Steps:                                   │
echo    │                                                 │
echo    │  1. Start server:  mix phx.server              │
echo    │  2. Create/join a room                         │
echo    │  3. Add YouTube videos to test                 │
echo    │                                                 │
echo    │  Note: Click anywhere on page first for        │
echo    │  autoplay (browser security requirement)       │
echo    └─────────────────────────────────────────────────┘
echo.
echo    Press any key to exit...
pause >nul
