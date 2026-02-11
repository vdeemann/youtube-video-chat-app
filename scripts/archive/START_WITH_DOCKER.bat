@echo off
echo.
echo ========================================
echo  QUICK FIX - Using Docker
echo ========================================
echo.
echo The bcrypt error needs Visual Studio Build Tools.
echo Docker is the fastest solution!
echo.
echo Starting server with Docker...
echo.
pause

docker-compose up --build

echo.
echo If Docker command failed, make sure Docker Desktop is running.
echo.
pause
