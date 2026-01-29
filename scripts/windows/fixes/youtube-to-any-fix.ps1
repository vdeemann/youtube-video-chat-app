# YouTube Auto-Advance to ANY Media Type
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "   YOUTUBE AUTO-ADVANCE TO ANY TRACK (YouTube/SoundCloud)    " -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

Set-Location "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

Write-Host "This fix ensures YouTube videos automatically advance to:" -ForegroundColor Yellow
Write-Host "  ✅ Next YouTube video in queue" -ForegroundColor White
Write-Host "  ✅ Next SoundCloud track in queue" -ForegroundColor White
Write-Host "  ✅ ANY media type - completely automatic!" -ForegroundColor White
Write-Host ""

Write-Host "How it works:" -ForegroundColor Green
Write-Host "  1. Monitors YouTube video progress every 500ms" -ForegroundColor White
Write-Host "  2. Detects when video reaches the end" -ForegroundColor White
Write-Host "  3. Automatically triggers next track (any type)" -ForegroundColor White
Write-Host "  4. No manual intervention needed!" -ForegroundColor White
Write-Host ""

Write-Host "Test Sequence:" -ForegroundColor Yellow
Write-Host "  YouTube (30s) → SoundCloud → YouTube (30s)" -ForegroundColor White
Write-Host ""

Write-Host "🧹 Stopping containers..." -ForegroundColor Yellow
docker-compose down

Write-Host ""
Write-Host "🔨 Building with complete auto-advance..." -ForegroundColor Yellow
docker-compose build web

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "    AUTO-ADVANCE ENABLED FOR ALL MEDIA TYPES!                " -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Expected behavior:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  YouTube → SoundCloud:" -ForegroundColor Cyan
Write-Host "    [YouTube] Video plays to end" -ForegroundColor Gray
Write-Host "    [YouTube] 🎬 VIDEO ENDED - ADVANCING TO NEXT" -ForegroundColor Gray
Write-Host "    [SoundCloud] Starts playing automatically" -ForegroundColor Gray
Write-Host ""
Write-Host "  YouTube → YouTube:" -ForegroundColor Cyan
Write-Host "    [YouTube #1] Video plays to end" -ForegroundColor Gray
Write-Host "    [YouTube #1] 🎬 VIDEO ENDED - ADVANCING TO NEXT" -ForegroundColor Gray
Write-Host "    [YouTube #2] Starts playing automatically" -ForegroundColor Gray
Write-Host ""

Write-Host "Test URLs:" -ForegroundColor Yellow
Write-Host "  1. YouTube (30s): https://www.youtube.com/watch?v=aqz-KE-bpKQ" -ForegroundColor White
Write-Host "  2. SoundCloud: https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew" -ForegroundColor White
Write-Host "  3. YouTube (30s): https://www.youtube.com/watch?v=Il-an3K9pjg" -ForegroundColor White
Write-Host ""

Write-Host "Starting app at http://localhost:4000" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

docker-compose up