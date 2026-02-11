@echo off
title YouTube Watch Party - Quick Start

echo ========================================
echo    YOUTUBE WATCH PARTY - QUICK START
echo ========================================
echo.
echo Starting your app with Docker...
echo.
echo This will:
echo  1. Check if Docker is running
echo  2. Start the application
echo  3. Open at http://localhost:4000
echo.
echo ========================================
echo.

REM Navigate to the project directory
cd /d "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

REM Try to start with docker-compose
docker-compose up

REM If docker-compose failed, show error message
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo    ERROR: Could not start the app!
    echo ========================================
    echo.
    echo Possible issues:
    echo  - Docker Desktop is not running
    echo  - Docker is not installed
    echo  - Port 4000 is already in use
    echo.
    echo Solutions:
    echo  1. Start Docker Desktop from Start Menu
    echo  2. Run troubleshoot-windows.ps1
    echo  3. Check WINDOWS_DOCKER_GUIDE.md
    echo.
)

pause
