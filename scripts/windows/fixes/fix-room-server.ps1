# Fix Room Server Initialization Error
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "    FIXING ROOM SERVER INITIALIZATION ERROR    " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project directory
Set-Location "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

Write-Host "📋 Fix Applied:" -ForegroundColor Green
Write-Host ""
Write-Host "  ✅ RoomServer now starts BEFORE getting state" -ForegroundColor White
Write-Host "  ✅ Handles case when server not found" -ForegroundColor White
Write-Host "  ✅ Provides default values if server unavailable" -ForegroundColor White
Write-Host "  ✅ Prevents MatchError crash" -ForegroundColor White
Write-Host ""

Write-Host "🧹 Stopping containers..." -ForegroundColor Yellow
docker-compose down

Write-Host ""
Write-Host "🔨 Rebuilding with fix..." -ForegroundColor Yellow
docker-compose build web

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "           STARTING FIXED APPLICATION          " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The app will be available at: http://localhost:4000" -ForegroundColor Cyan
Write-Host ""
Write-Host "The room server error has been fixed!" -ForegroundColor Green
Write-Host "You should now be able to:" -ForegroundColor Yellow
Write-Host "  • Create new rooms" -ForegroundColor White
Write-Host "  • Join existing rooms" -ForegroundColor White
Write-Host "  • Add tracks to queue" -ForegroundColor White
Write-Host "  • Enjoy synchronized playback" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
Write-Host ""

docker-compose up