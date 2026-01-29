# Fix SoundCloud Playback Issue
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "     FIXING SOUNDCLOUD PLAYBACK ISSUE          " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project directory
Set-Location "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

Write-Host "Applied fixes:" -ForegroundColor Green
Write-Host "✅ Set auto_play=true in SoundCloud embed URLs" -ForegroundColor White
Write-Host "✅ Improved SoundCloud Widget API initialization" -ForegroundColor White
Write-Host "✅ Added retry logic for widget loading" -ForegroundColor White
Write-Host "✅ Enhanced error handling and recovery" -ForegroundColor White
Write-Host ""

# Check if Docker is running
$dockerRunning = docker info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker is not running!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop first." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "🧹 Stopping existing containers..." -ForegroundColor Yellow
docker-compose down

Write-Host ""
Write-Host "🔨 Rebuilding with SoundCloud fixes..." -ForegroundColor Yellow
docker-compose build web

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "🚀 Starting the application..." -ForegroundColor Green
Write-Host "The app will be available at: http://localhost:4000" -ForegroundColor Cyan
Write-Host ""
Write-Host "SoundCloud tracks should now play automatically!" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
Write-Host ""

docker-compose up