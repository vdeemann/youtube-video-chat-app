# Fix YouTube Auto-Advance Issue
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "     FIXING YOUTUBE VIDEO AUTO-ADVANCE         " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project directory
Set-Location "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

Write-Host "📋 YouTube Player Fixes Applied:" -ForegroundColor Green
Write-Host ""

Write-Host "Enhanced End Detection:" -ForegroundColor Yellow
Write-Host "  ✅ Better YouTube API message handling" -ForegroundColor White
Write-Host "  ✅ Added progress monitoring fallback" -ForegroundColor White
Write-Host "  ✅ Detects stuck videos at end" -ForegroundColor White
Write-Host "  ✅ Comprehensive state logging" -ForegroundColor White
Write-Host "  ✅ Ensures enablejsapi=1 in URLs" -ForegroundColor White
Write-Host ""

Write-Host "Expected Console Output:" -ForegroundColor Yellow
Write-Host "  [YouTube] State changed to: 1 (playing)" -ForegroundColor Gray
Write-Host "  [YouTube] State changed to: 0 (ended)" -ForegroundColor Gray
Write-Host "  [YouTube] 🎬 VIDEO ENDED - Triggering auto-advance" -ForegroundColor Gray
Write-Host "  === VIDEO_ENDED EVENT ===" -ForegroundColor Gray
Write-Host "  === PLAY NEXT CALLED ===" -ForegroundColor Gray
Write-Host ""

Write-Host "🧹 Stopping containers..." -ForegroundColor Yellow
docker-compose down

Write-Host ""
Write-Host "🔨 Rebuilding with YouTube fix..." -ForegroundColor Yellow
docker-compose build web

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "        STARTING WITH YOUTUBE FIX              " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The app will be available at: http://localhost:4000" -ForegroundColor Cyan
Write-Host ""

Write-Host "🧪 Test with Short YouTube Videos:" -ForegroundColor Yellow
Write-Host "  30 seconds: https://www.youtube.com/watch?v=aqz-KE-bpKQ" -ForegroundColor White
Write-Host "  30 seconds: https://www.youtube.com/watch?v=Il-an3K9pjg" -ForegroundColor White
Write-Host "  1 minute:   https://www.youtube.com/watch?v=FTQbiNvZqaY" -ForegroundColor White
Write-Host ""

Write-Host "✅ YouTube videos should now:" -ForegroundColor Green
Write-Host "  • Detect when they end" -ForegroundColor White
Write-Host "  • Auto-advance to next track in queue" -ForegroundColor White
Write-Host "  • Be removed from NOW PLAYING" -ForegroundColor White
Write-Host "  • Trigger the next SoundCloud/YouTube" -ForegroundColor White
Write-Host ""

Write-Host "⚠️ Important:" -ForegroundColor Yellow
Write-Host "  • You must be the HOST (see Skip button)" -ForegroundColor White
Write-Host "  • Keep browser console open (F12)" -ForegroundColor White
Write-Host "  • Watch for state change messages" -ForegroundColor White
Write-Host ""

Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
Write-Host ""

docker-compose up