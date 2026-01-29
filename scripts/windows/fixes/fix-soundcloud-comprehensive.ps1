# Comprehensive SoundCloud Fix for Windows
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   COMPREHENSIVE SOUNDCLOUD PLAYBACK FIX       " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project directory
Set-Location "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

Write-Host "📋 Applied fixes:" -ForegroundColor Green
Write-Host ""
Write-Host "Backend Changes:" -ForegroundColor Yellow
Write-Host "  ✅ Updated embed URL with more parameters" -ForegroundColor White
Write-Host "  ✅ Added callback=true for better API support" -ForegroundColor White
Write-Host "  ✅ Added manual play event handler" -ForegroundColor White
Write-Host ""
Write-Host "Frontend Changes:" -ForegroundColor Yellow
Write-Host "  ✅ Complete rewrite of SoundCloud Widget handling" -ForegroundColor White
Write-Host "  ✅ Added robust retry logic (up to 10 attempts)" -ForegroundColor White
Write-Host "  ✅ Better state checking and error recovery" -ForegroundColor White
Write-Host "  ✅ Multiple play attempts with different methods" -ForegroundColor White
Write-Host "  ✅ Manual play button as fallback (for host)" -ForegroundColor White
Write-Host "  ✅ Volume control to ensure audio is audible" -ForegroundColor White
Write-Host ""

# Check if Docker is running
$dockerRunning = docker info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker is not running!" -ForegroundColor Red
    Write-Host "Starting Docker Desktop..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    
    Write-Host "Waiting for Docker to start (up to 60 seconds)..." -ForegroundColor Yellow
    $timeout = 60
    $counter = 0
    while ($counter -lt $timeout) {
        Start-Sleep -Seconds 2
        $counter += 2
        Write-Host "." -NoNewline
        $dockerRunning = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✅ Docker is now running!" -ForegroundColor Green
            break
        }
    }
    
    if ($counter -ge $timeout) {
        Write-Host ""
        Write-Host "❌ Docker failed to start. Please start it manually." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host "🧹 Cleaning up old containers..." -ForegroundColor Yellow
docker-compose down -v 2>$null

Write-Host ""
Write-Host "🔨 Building fresh container with all fixes..." -ForegroundColor Yellow
docker-compose build --no-cache web

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
Write-Host "🎵 SoundCloud Playback Instructions:" -ForegroundColor Yellow
Write-Host "  1. Add a SoundCloud URL to the queue" -ForegroundColor White
Write-Host "  2. The track should auto-play when loaded" -ForegroundColor White
Write-Host "  3. If not, click the orange play button (host only)" -ForegroundColor White
Write-Host "  4. Check browser console (F12) for debug info" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
Write-Host ""

docker-compose up