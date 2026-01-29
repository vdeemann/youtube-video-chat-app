Write-Host "========================================" -ForegroundColor Cyan
Write-Host "YOUTUBE PLAYER FULL-SIZE LAYOUT FIX" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This fix maximizes the YouTube player to use all available" -ForegroundColor Green
Write-Host "screen space between the header and chat input area." -ForegroundColor Green
Write-Host ""
Write-Host "Changes made:" -ForegroundColor White
Write-Host "- Player fills space from header to chat input" -ForegroundColor Gray
Write-Host "- YouTube controls visible above chat area" -ForegroundColor Gray
Write-Host "- Maintains 16:9 aspect ratio" -ForegroundColor Gray
Write-Host "- Maximizes viewing area" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPILING ASSETS..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Set-Location assets
npm run deploy 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to compile assets" -ForegroundColor Red
    Write-Host "Try running: cd assets && npm install" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "     Done!" -ForegroundColor Green
Set-Location ..

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RECOMPILING ELIXIR CODE..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

mix compile --force 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to compile" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "     Done!" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "FIX APPLIED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The YouTube player now:" -ForegroundColor Yellow
Write-Host "- Uses maximum available screen space" -ForegroundColor White
Write-Host "- Shows controls just above chat input" -ForegroundColor White
Write-Host "- Maintains proper aspect ratio" -ForegroundColor White
Write-Host "- Provides immersive viewing experience" -ForegroundColor White
Write-Host ""
Write-Host "Layout details:" -ForegroundColor Yellow
Write-Host "- Top: Aligned with header (76px)" -ForegroundColor Gray
Write-Host "- Bottom: Aligned with chat input (100px)" -ForegroundColor Gray
Write-Host "- Width: Auto-calculated for 16:9 ratio" -ForegroundColor Gray
Write-Host ""
Write-Host "Restart your Phoenix server to see changes:" -ForegroundColor Yellow
Write-Host "  mix phx.server" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
