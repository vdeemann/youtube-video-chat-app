@echo off
echo.
echo ========================================
echo  WORKAROUND - Bypass bcrypt
echo ========================================
echo.
echo This will temporarily disable bcrypt so you can
echo test the queue fix without installing build tools.
echo.
echo WARNING: This disables password features, but the
echo queue system will work fine for testing!
echo.
pause

echo.
echo [1/4] Backing up original mix.exs...
copy mix.exs mix.exs.backup

echo.
echo [2/4] Installing mix.exs without bcrypt...
copy /Y mix.exs.no_bcrypt mix.exs

echo.
echo [3/4] Cleaning and getting dependencies...
call mix deps.clean bcrypt_elixir --unlock
call mix deps.get

echo.
echo [4/4] Starting server...
echo.
echo ========================================
echo  Server Starting (No Password Features)
echo ========================================
echo.
echo Opening browser in 3 seconds...
timeout /t 3 /nobreak >nul
start http://localhost:4000/rooms

call mix phx.server

echo.
echo.
echo To restore bcrypt later, run:
echo   copy mix.exs.backup mix.exs
echo   mix deps.get
echo.
pause
