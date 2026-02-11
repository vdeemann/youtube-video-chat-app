@echo off
echo.
echo =============================================
echo  CLEANING UP PROJECT STRUCTURE
echo =============================================
echo.
echo This will:
echo  1. Move all temp docs to docs/archive
echo  2. Move all temp scripts to scripts/archive
echo  3. Keep only essential files in root
echo  4. Create a clean structure
echo.
pause

REM Create archive directories
if not exist "docs\archive" mkdir "docs\archive"
if not exist "scripts\archive" mkdir "scripts\archive"

echo.
echo Moving temporary documentation...

REM Move temp docs to archive
move /Y "ACTUALLY_SIMPLE.md" "docs\archive\" 2>nul
move /Y "DOCKER_QUEUE_FIX.md" "docs\archive\" 2>nul
move /Y "DURATION_DETECTION.md" "docs\archive\" 2>nul
move /Y "DURATION_EXPLAINED.md" "docs\archive\" 2>nul
move /Y "FIX_BCRYPT_ERROR.md" "docs\archive\" 2>nul
move /Y "INSTANT_ADVANCEMENT.md" "docs\archive\" 2>nul
move /Y "INSTANT_QUEUE_ADVANCEMENT.md" "docs\archive\" 2>nul
move /Y "QUEUE_FIX_ARCHITECTURE.md" "docs\archive\" 2>nul
move /Y "QUEUE_FIX_QUICK_REF.md" "docs\archive\" 2>nul
move /Y "QUEUE_FIX_README.md" "docs\archive\" 2>nul
move /Y "QUEUE_FIX_SUMMARY.md" "docs\archive\" 2>nul
move /Y "QUEUE_QUICK_START.md" "docs\archive\" 2>nul
move /Y "QUEUE_SYSTEM_ARCHITECTURE.md" "docs\archive\" 2>nul
move /Y "QUEUE_SYSTEM_FIX.md" "docs\archive\" 2>nul
move /Y "README_APPLY_FIX.txt" "docs\archive\" 2>nul
move /Y "REMOVE_PAUSE.md" "docs\archive\" 2>nul
move /Y "SIMPLIFIED_QUEUE_README.md" "docs\archive\" 2>nul
move /Y "START_HERE.md" "docs\archive\" 2>nul
move /Y "SUCCESS.md" "docs\archive\" 2>nul
move /Y "TEST_INSTANT_ADVANCEMENT.md" "docs\archive\" 2>nul
move /Y "TROUBLESHOOTING.md" "docs\archive\" 2>nul

echo Moving temporary scripts...

REM Move temp scripts to archive
move /Y "APPLY_FIX.bat" "scripts\archive\" 2>nul
move /Y "APPLY_FIX_NOW.bat" "scripts\archive\" 2>nul
move /Y "apply_instant_fix.bat" "scripts\archive\" 2>nul
move /Y "apply_instant_fix.sh" "scripts\archive\" 2>nul
move /Y "APPLY_QUEUE_FIX.bat" "scripts\archive\" 2>nul
move /Y "check_js_rebuild.sh" "scripts\archive\" 2>nul
move /Y "cleanup_project.sh" "scripts\archive\" 2>nul
move /Y "diagnose_js.sh" "scripts\archive\" 2>nul
move /Y "FIX_NOW.bat" "scripts\archive\" 2>nul
move /Y "nuclear_rebuild.sh" "scripts\archive\" 2>nul
move /Y "QUICK-FIX-QUEUE.bat" "scripts\archive\" 2>nul
move /Y "REBUILD_ASSETS_DOCKER.bat" "scripts\archive\" 2>nul
move /Y "REBUILD_DOCKER.bat" "scripts\archive\" 2>nul
move /Y "SIMPLE_FIX.bat" "scripts\archive\" 2>nul
move /Y "SIMPLIFIED_FIX.bat" "scripts\archive\" 2>nul
move /Y "START_SERVER.bat" "scripts\archive\" 2>nul
move /Y "START_WITH_DOCKER.bat" "scripts\archive\" 2>nul
move /Y "TEST-QUEUE-FIX.bat" "scripts\archive\" 2>nul
move /Y "test_queue.sh" "scripts\archive\" 2>nul
move /Y "WORKAROUND_NO_BCRYPT.bat" "scripts\archive\" 2>nul

REM Remove backup file
del /F /Q "mix.exs.no_bcrypt" 2>nul

echo.
echo =============================================
echo  CLEANUP COMPLETE!
echo =============================================
echo.
echo Cleaned structure:
echo.
echo  Root directory:
echo    - Only essential Phoenix files
echo    - README.md (main documentation)
echo    - docker-compose.yml
echo    - Dockerfile, Dockerfile.dev
echo.
echo  docs/archive:
echo    - All temporary documentation
echo.
echo  scripts/archive:
echo    - All temporary scripts
echo.
echo Your project is now clean and organized!
echo.
pause
