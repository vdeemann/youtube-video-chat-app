Write-Host "========================================" -ForegroundColor Cyan
Write-Host "YOUTUBE AUTO-PLAY FIX" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This fix enables automatic playback when YouTube videos are added to the queue." -ForegroundColor Green
Write-Host ""
Write-Host "Changes made:" -ForegroundColor White
Write-Host "- YouTube embed URLs now use autoplay=1 instead of autoplay=0" -ForegroundColor Gray
Write-Host "- JavaScript ensures autoplay parameter is set when loading videos" -ForegroundColor Gray
Write-Host "- Both initial load and queue advancement will auto-play" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPILING ASSETS..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Set-Location assets
npm run deploy
Set-Location ..

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RECOMPILING ELIXIR CODE..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

mix deps.get
mix compile --force

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "FIX APPLIED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "To test the fix:" -ForegroundColor Yellow
Write-Host "1. Start the server: mix phx.server" -ForegroundColor White
Write-Host "2. Create or join a room" -ForegroundColor White
Write-Host "3. Add a YouTube video to the queue" -ForegroundColor White
Write-Host "4. The video should start playing automatically" -ForegroundColor White
Write-Host ""
Write-Host "Note: Some browsers may require user interaction (click) on the page" -ForegroundColor Yellow
Write-Host "before allowing autoplay with sound. If videos don't auto-play:" -ForegroundColor Yellow
Write-Host "- Try clicking anywhere on the page first" -ForegroundColor Gray
Write-Host "- Check browser autoplay settings" -ForegroundColor Gray
Write-Host "- Consider using mute=1 for guaranteed autoplay (but no sound)" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
