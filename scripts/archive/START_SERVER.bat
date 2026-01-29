@echo off
echo.
echo Starting Phoenix server...
echo The JavaScript fix will be compiled automatically.
echo.
echo Opening browser in 3 seconds...
timeout /t 3 /nobreak >nul

start http://localhost:4000/rooms

echo.
echo ========================================
echo TEST: Add 2-3 videos and watch them
echo auto-advance when each one finishes!
echo ========================================
echo.

mix phx.server
