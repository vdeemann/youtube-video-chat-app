@echo off
echo.
echo ========================================
echo  REBUILD ASSETS IN RUNNING CONTAINER
echo ========================================
echo.
echo This will rebuild the JavaScript assets
echo with your queue fix inside the running
echo Docker container.
echo.

echo Step 1: Rebuilding assets...
docker-compose exec web mix assets.build

if errorlevel 1 (
    echo.
    echo Assets rebuild failed. Container might not be running.
    echo.
    echo Starting fresh with rebuild...
    docker-compose down
    docker-compose up --build
) else (
    echo.
    echo ========================================
    echo  SUCCESS!
    echo ========================================
    echo.
    echo Assets rebuilt! The queue auto-advancement
    echo fix is now active.
    echo.
    echo Refresh your browser (Ctrl+F5) and test!
    echo.
    echo The server is still running.
    echo Watch the logs for "VIDEO ENDED" events.
    echo.
)

pause
