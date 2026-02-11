@echo off
color 0A
title Queue Fix - Auto-Advancement for YouTube & SoundCloud

echo.
echo  ═══════════════════════════════════════════════════════
echo   QUEUE AUTO-ADVANCEMENT FIX
echo   YouTube Video Chat App
echo  ═══════════════════════════════════════════════════════
echo.
echo  This script will:
echo   • Stop any running servers
echo   • Rebuild JavaScript with the fix
echo   • Start the Phoenix server
echo   • Open your browser for testing
echo.
echo  ═══════════════════════════════════════════════════════
echo.
pause

REM Change to script directory
cd /d "%~dp0"

echo.
echo [1/4] Stopping any running Phoenix servers...
echo ───────────────────────────────────────────────────────
taskkill /F /IM beam.smp.exe 2>nul && echo   ✓ Stopped beam.smp.exe || echo   • No beam.smp.exe running
taskkill /F /IM erl.exe 2>nul && echo   ✓ Stopped erl.exe || echo   • No erl.exe running
echo   Waiting for processes to fully stop...
timeout /t 2 /nobreak >nul
echo   ✓ Complete

echo.
echo [2/4] Rebuilding JavaScript assets...
echo ───────────────────────────────────────────────────────
echo   Compiling MediaPlayer hook with auto-advancement fix...
echo.

call mix assets.build

if errorlevel 1 (
    echo.
    echo  ═══════════════════════════════════════════════════════
    echo   ❌ ERROR: Asset build failed!
    echo  ═══════════════════════════════════════════════════════
    echo.
    echo   Possible issues:
    echo   • Elixir/Erlang not installed
    echo   • Mix dependencies not installed
    echo   • esbuild not configured
    echo.
    echo   Try these commands:
    echo   1. mix deps.get
    echo   2. mix deps.compile
    echo   3. Run this script again
    echo.
    pause
    exit /b 1
)

echo.
echo   ✓ JavaScript assets rebuilt successfully!

echo.
echo [3/4] Verifying fix...
echo ───────────────────────────────────────────────────────
if exist "priv\static\assets\app.js" (
    echo   ✓ app.js exists
) else (
    echo   ❌ app.js not found - build may have failed
)

if exist "assets\js\hooks\media_player.js" (
    findstr /C:"COMPREHENSIVE MediaPlayer" "assets\js\hooks\media_player.js" >nul
    if errorlevel 1 (
        echo   ❌ MediaPlayer hook not updated
    ) else (
        echo   ✓ MediaPlayer hook verified
    )
) else (
    echo   ❌ media_player.js not found
)

echo.
echo [4/4] Starting Phoenix server...
echo ───────────────────────────────────────────────────────
echo.
echo  ═══════════════════════════════════════════════════════
echo   ✓ FIX APPLIED SUCCESSFULLY!
echo  ═══════════════════════════════════════════════════════
echo.
echo   Your browser will open automatically...
echo.
echo   🎯 TEST STEPS:
echo   ──────────────────────────────────────────────────────
echo   1. Create or join a room (you'll be the host)
echo   2. Add 2-3 videos/tracks:
echo      • YouTube: https://youtu.be/dQw4w9WgXcQ
echo      • SoundCloud: any track URL
echo   3. Let the first one play completely
echo   4. Watch it auto-advance to the next! ✨
echo.
echo   📊 DEBUGGING:
echo   ──────────────────────────────────────────────────────
echo   • Open browser console (F12) for detailed logs
echo   • Look for "VIDEO ENDED" messages
echo   • Server logs will show "VIDEO_ENDED EVENT"
echo.
echo   Press Ctrl+C to stop the server
echo  ═══════════════════════════════════════════════════════
echo.

timeout /t 3 /nobreak >nul

REM Open browser
start http://localhost:4000/rooms

REM Start server
call mix phx.server
