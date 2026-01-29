# Fix Auto-Advance for Queue System
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "      FIXING AUTO-ADVANCE QUEUE ISSUES         " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project directory
Set-Location "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

Write-Host "📋 Auto-Advance Fixes Applied:" -ForegroundColor Green
Write-Host ""

Write-Host "JavaScript Changes:" -ForegroundColor Yellow
Write-Host "  ✅ Fixed MediaPlayer hook import in app.js" -ForegroundColor White
Write-Host "  ✅ Removed fallback inline hook definition" -ForegroundColor White
Write-Host "  ✅ Proper ES6 import for hooks" -ForegroundColor White
Write-Host ""

Write-Host "Backend Changes:" -ForegroundColor Yellow
Write-Host "  ✅ Added detailed logging for video_ended event" -ForegroundColor White
Write-Host "  ✅ Enhanced debug output for queue operations" -ForegroundColor White
Write-Host "  ✅ Better tracking of media changes" -ForegroundColor White
Write-Host ""

Write-Host "Expected Behavior:" -ForegroundColor Yellow
Write-Host "  • When a track ends, it auto-advances to next" -ForegroundColor White
Write-Host "  • Current track is removed from 'Now Playing'" -ForegroundColor White
Write-Host "  • Next track starts playing automatically" -ForegroundColor White
Write-Host "  • Queue updates for all users simultaneously" -ForegroundColor White
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
Write-Host "🔨 Rebuilding with auto-advance fixes..." -ForegroundColor Yellow
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
Write-Host "🔍 How to Test Auto-Advance:" -ForegroundColor Yellow
Write-Host "  1. Add a SoundCloud track to queue" -ForegroundColor White
Write-Host "  2. Add 2 YouTube videos after it" -ForegroundColor White
Write-Host "  3. Let the SoundCloud track play to the end" -ForegroundColor White
Write-Host "  4. Should auto-advance to first YouTube video" -ForegroundColor White
Write-Host ""
Write-Host "📊 Console Messages to Watch For:" -ForegroundColor Yellow
Write-Host "  [SoundCloud] ✅ FINISHED - advancing to next track" -ForegroundColor White
Write-Host "  === VIDEO_ENDED EVENT ===" -ForegroundColor White
Write-Host "  === PLAY NEXT CALLED ===" -ForegroundColor White
Write-Host "  Playing next track: [track name]" -ForegroundColor White
Write-Host ""
Write-Host "⚠️ Important:" -ForegroundColor Yellow
Write-Host "  • Only the HOST triggers auto-advance" -ForegroundColor White
Write-Host "  • Check browser console (F12) for debug info" -ForegroundColor White
Write-Host "  • Ensure you're the host (purple Skip button visible)" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
Write-Host ""

docker-compose up