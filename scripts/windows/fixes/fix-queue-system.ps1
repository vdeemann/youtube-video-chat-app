# Fix Queue System for Windows
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "      FIXING QUEUE SYSTEM & AUTO-ADVANCE       " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project directory
Set-Location "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

Write-Host "📋 Queue System Fixes Applied:" -ForegroundColor Green
Write-Host ""

Write-Host "Backend Changes (RoomServer):" -ForegroundColor Yellow
Write-Host "  ✅ Separated current media from queue" -ForegroundColor White
Write-Host "  ✅ Queue now only shows upcoming tracks" -ForegroundColor White
Write-Host "  ✅ Improved logging for debugging" -ForegroundColor White
Write-Host "  ✅ Fixed synchronization broadcasts" -ForegroundColor White
Write-Host ""

Write-Host "Frontend Changes (Template):" -ForegroundColor Yellow
Write-Host "  ✅ Added 'Now Playing' section" -ForegroundColor White
Write-Host "  ✅ Added 'Up Next' section with numbering" -ForegroundColor White
Write-Host "  ✅ Queue badge shows count" -ForegroundColor White
Write-Host "  ✅ Better visual distinction" -ForegroundColor White
Write-Host "  ✅ Animated playing indicator" -ForegroundColor White
Write-Host ""

Write-Host "JavaScript Changes (MediaPlayer):" -ForegroundColor Yellow
Write-Host "  ✅ Improved end detection for both platforms" -ForegroundColor White
Write-Host "  ✅ Prevents duplicate end events" -ForegroundColor White
Write-Host "  ✅ Better state tracking" -ForegroundColor White
Write-Host "  ✅ Progress monitoring for debugging" -ForegroundColor White
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

Write-Host "🧹 Stopping existing containers..." -ForegroundColor Yellow
docker-compose down

Write-Host ""
Write-Host "🔨 Rebuilding with queue fixes..." -ForegroundColor Yellow
docker-compose build web

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "         STARTING FIXED APPLICATION            " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The app will be available at: http://localhost:4000" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎵 Queue System Features:" -ForegroundColor Yellow
Write-Host "  • Tracks play in order automatically" -ForegroundColor White
Write-Host "  • 'Now Playing' shows current track" -ForegroundColor White
Write-Host "  • 'Up Next' shows queued tracks with numbers" -ForegroundColor White
Write-Host "  • Auto-advance when track ends" -ForegroundColor White
Write-Host "  • All users see synchronized queue" -ForegroundColor White
Write-Host "  • Host can skip or remove tracks" -ForegroundColor White
Write-Host ""
Write-Host "🧪 Testing Instructions:" -ForegroundColor Yellow
Write-Host "  1. Add multiple YouTube/SoundCloud URLs" -ForegroundColor White
Write-Host "  2. Watch them play in sequence" -ForegroundColor White
Write-Host "  3. Check browser console (F12) for progress" -ForegroundColor White
Write-Host "  4. Open multiple browsers to test sync" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
Write-Host ""

docker-compose up