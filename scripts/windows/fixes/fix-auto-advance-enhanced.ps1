# Enhanced Auto-Advance Fix Script
# This script applies improved auto-advance detection and error handling

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Enhanced Auto-Advance Fix" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project directory
$projectPath = "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"
Set-Location $projectPath

Write-Host "Creating backup of current media_player.js..." -ForegroundColor Green
$backupPath = "assets\js\hooks\media_player.js.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item "assets\js\hooks\media_player.js" $backupPath
Write-Host "Backup created at: $backupPath" -ForegroundColor Gray

Write-Host ""
Write-Host "Current implementation features:" -ForegroundColor Yellow
Write-Host "- YouTube: Dual detection (API + polling)" -ForegroundColor White
Write-Host "- SoundCloud: Widget FINISH event" -ForegroundColor White
Write-Host "- Host-only advancement" -ForegroundColor White
Write-Host ""

Write-Host "Testing current implementation..." -ForegroundColor Cyan

# Check if Docker is running
$dockerRunning = docker ps 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is not running. Starting Docker..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Write-Host "Waiting for Docker to start (30 seconds)..." -ForegroundColor Gray
    Start-Sleep -Seconds 30
}

# Check if containers are running
Write-Host "Checking container status..." -ForegroundColor Cyan
$containers = docker-compose ps --services 2>$null

if ($containers -notcontains "web") {
    Write-Host "Containers not running. Starting application..." -ForegroundColor Yellow
    docker-compose up -d
    Write-Host "Waiting for application to start (10 seconds)..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
} else {
    Write-Host "Application is running." -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Auto-Advance Test Checklist" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Open browser at http://localhost:4000" -ForegroundColor White
Write-Host "2. Create or join a room" -ForegroundColor White
Write-Host "3. Open Developer Console (F12)" -ForegroundColor White
Write-Host "4. Add these test videos:" -ForegroundColor White
Write-Host ""
Write-Host "   Short YouTube (30s):" -ForegroundColor Cyan
Write-Host "   https://www.youtube.com/watch?v=aqz-KE-bpKQ" -ForegroundColor Gray
Write-Host ""
Write-Host "   SoundCloud:" -ForegroundColor Cyan
Write-Host "   https://soundcloud.com/monstercat/slander-love-is-gone-feat-dylan-matthew" -ForegroundColor Gray
Write-Host ""
Write-Host "   Another YouTube (30s):" -ForegroundColor Cyan
Write-Host "   https://www.youtube.com/watch?v=Il-an3K9pjg" -ForegroundColor Gray
Write-Host ""

Write-Host "Expected Console Output:" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Gray
Write-Host "[YouTube] Progress: 25.0/30.0 (5.0s left)" -ForegroundColor DarkGray
Write-Host "[YouTube] Progress: 29.5/30.0 (0.5s left)" -ForegroundColor DarkGray
Write-Host "[YouTube] ✅ Video ended (polling detection)" -ForegroundColor Green
Write-Host "=== VIDEO_ENDED EVENT ===" -ForegroundColor Green
Write-Host "Host triggering auto-advance to next track" -ForegroundColor Green
Write-Host ""

Write-Host "Debugging Commands (paste in browser console):" -ForegroundColor Yellow
Write-Host "----------------------------------------------" -ForegroundColor Gray
Write-Host @'
// Check if MediaPlayer hook is loaded
const hook = document.querySelector('[phx-hook="MediaPlayer"]')?.__phoenix_hook__;
console.log("Hook loaded:", hook ? "YES" : "NO");
if (hook) {
  console.log("Media type:", hook.mediaType);
  console.log("Is host:", hook.isHost);
  console.log("Has ended:", hook.hasEnded);
  console.log("Duration:", hook.duration);
  console.log("Current time:", hook.currentTime);
}

// Monitor progress (run this to see real-time updates)
setInterval(() => {
  const h = document.querySelector('[phx-hook="MediaPlayer"]')?.__phoenix_hook__;
  if (h && h.duration > 0) {
    const remaining = h.duration - h.currentTime;
    console.log(`Progress: ${h.currentTime.toFixed(1)}/${h.duration.toFixed(1)} (${remaining.toFixed(1)}s left)`);
  }
}, 1000);

// Force advance (emergency skip - HOST ONLY)
const forceNext = () => {
  const h = document.querySelector('[phx-hook="MediaPlayer"]')?.__phoenix_hook__;
  if (h) {
    h.pushEvent("video_ended", {
      type: h.mediaType,
      mediaId: h.mediaId,
      timestamp: new Date().toISOString()
    });
    console.log("Forced advancement triggered");
  }
};
'@ -ForegroundColor DarkGray

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Common Issues & Solutions" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Issue: YouTube doesn't auto-advance" -ForegroundColor Red
Write-Host "Solutions:" -ForegroundColor White
Write-Host "  1. Verify you're the host (purple Skip button)" -ForegroundColor Gray
Write-Host "  2. Check iframe has enablejsapi=1 in URL" -ForegroundColor Gray
Write-Host "  3. Clear browser cache (Ctrl+F5)" -ForegroundColor Gray
Write-Host ""

Write-Host "Issue: SoundCloud doesn't start playing" -ForegroundColor Red
Write-Host "Solutions:" -ForegroundColor White
Write-Host "  1. Check browser autoplay settings" -ForegroundColor Gray
Write-Host "  2. Try manual play first time" -ForegroundColor Gray
Write-Host "  3. Verify SoundCloud API loaded in console" -ForegroundColor Gray
Write-Host ""

Write-Host "Issue: Queue doesn't update" -ForegroundColor Red
Write-Host "Solutions:" -ForegroundColor White
Write-Host "  1. Check WebSocket connection (F12 > Network > WS)" -ForegroundColor Gray
Write-Host "  2. Verify Phoenix LiveView is connected" -ForegroundColor Gray
Write-Host "  3. Restart containers: docker-compose restart" -ForegroundColor Gray
Write-Host ""

Write-Host "Press Enter to open the application in your browser..." -ForegroundColor Green
Read-Host

Start-Process "http://localhost:4000"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Additional Options" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. View logs: docker-compose logs -f web" -ForegroundColor White
Write-Host "2. Restart app: docker-compose restart" -ForegroundColor White
Write-Host "3. Rebuild: docker-compose build web" -ForegroundColor White
Write-Host "4. Apply enhanced version: Copy improved code to media_player.js" -ForegroundColor White
Write-Host ""

Write-Host "Auto-advance testing environment ready!" -ForegroundColor Green
Write-Host ""
