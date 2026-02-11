@echo off
echo ================================================
echo      YOUTUBE WATCH PARTY APP LAUNCHER
echo ================================================
echo.

REM Check if PowerShell script exists
if not exist "start-docker-windows.ps1" (
    echo ERROR: start-docker-windows.ps1 not found!
    echo Please ensure you're in the correct directory.
    pause
    exit /b 1
)

echo Starting application via PowerShell...
echo.

REM Run the PowerShell script
powershell.exe -ExecutionPolicy Bypass -File "start-docker-windows.ps1"

pause
