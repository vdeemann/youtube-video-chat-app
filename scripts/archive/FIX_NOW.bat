@echo off
color 0A
cls
echo.
echo  ============================================
echo   QUEUE FIX - ONE COMMAND SOLUTION
echo  ============================================
echo.
echo  This will activate the queue auto-advancement
echo  fix in your running Docker container.
echo.
echo  What this does:
echo  1. Rebuilds JavaScript assets in Docker
echo  2. Shows you what to do next
echo.
echo  ============================================
echo.
pause

cls
echo.
echo  Rebuilding assets in Docker container...
echo  ============================================
echo.

docker-compose exec web mix assets.build

echo.
echo  ============================================
echo   DONE! Now do these 3 things:
echo  ============================================
echo.
echo  1. Hard refresh your browser:
echo     Press Ctrl + F5
echo.
echo  2. Open browser console:
echo     Press F12
echo.
echo  3. Test the queue:
echo     - Add 2-3 videos
echo     - Let first one finish
echo     - Watch it auto-advance!
echo.
echo  Look for "VIDEO ENDED" in console and logs!
echo  ============================================
echo.
pause
