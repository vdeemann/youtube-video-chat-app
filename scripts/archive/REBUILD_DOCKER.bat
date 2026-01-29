@echo off
echo.
echo ========================================
echo  REBUILDING ASSETS IN DOCKER
echo ========================================
echo.
echo This will rebuild the JavaScript with the
echo queue auto-advancement fix inside Docker.
echo.
pause

echo.
echo [1/3] Stopping containers...
docker-compose down

echo.
echo [2/3] Rebuilding with no cache (forces fresh build)...
docker-compose build --no-cache web

echo.
echo [3/3] Starting server...
docker-compose up

echo.
pause
