@echo off
echo.
echo =============================================
echo  SIMPLIFIED QUEUE - REBUILD AND TEST
echo =============================================
echo.
echo Simplified changes:
echo  - Cleaner JavaScript (no extra detection)
echo  - Simpler logging
echo  - Same functionality
echo.
echo Rebuilding in Docker...
echo.

docker-compose exec web mix assets.build

echo.
echo =============================================
echo  DONE! Now test it:
echo =============================================
echo.
echo 1. Hard refresh browser (Ctrl + Shift + R)
echo 2. Open console (F12)
echo 3. Add 2 videos to queue
echo 4. Let first video finish
echo 5. Should auto-advance!
echo.
echo Look for in console:
echo   "=== VIDEO ENDED ==="
echo.
echo Look for in Docker logs:
echo   "[info] VIDEO ENDED - Host: true"
echo   "[info] Advancing to next track..."
echo.
pause
