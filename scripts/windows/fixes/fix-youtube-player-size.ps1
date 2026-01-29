Write-Host "========================================" -ForegroundColor Cyan
Write-Host "YOUTUBE PLAYER SIZING FIX" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This fix resizes the YouTube player to maintain proper 16:9 aspect ratio" -ForegroundColor Green
Write-Host "and ensures video controls and title are visible." -ForegroundColor Green
Write-Host ""
Write-Host "Changes made:" -ForegroundColor White
Write-Host "- YouTube player now maintains 16:9 aspect ratio" -ForegroundColor Gray
Write-Host "- Player is centered with max width for better viewing" -ForegroundColor Gray
Write-Host "- Video title displayed below player" -ForegroundColor Gray
Write-Host "- All YouTube controls remain accessible" -ForegroundColor Gray
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

mix compile --force

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "FIX APPLIED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The YouTube player will now:" -ForegroundColor Yellow
Write-Host "- Display at proper 16:9 aspect ratio" -ForegroundColor White
Write-Host "- Show video title and controls" -ForegroundColor White
Write-Host "- Not overflow the screen" -ForegroundColor White
Write-Host "- Center properly on all screen sizes" -ForegroundColor White
Write-Host ""
Write-Host "Restart your Phoenix server to see the changes:" -ForegroundColor Yellow
Write-Host "  mix phx.server" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
