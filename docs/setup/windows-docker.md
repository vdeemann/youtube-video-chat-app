# 🪟 Windows 11 Docker Setup Guide - YouTube Watch Party App

## 📋 Prerequisites for Windows 11

### 1. System Requirements
- Windows 11 (or Windows 10 version 2004 or higher)
- WSL 2 (Windows Subsystem for Linux) enabled
- 8GB RAM minimum (16GB recommended)
- Virtualization enabled in BIOS

### 2. Check Virtualization Status
Open PowerShell as Administrator and run:
```powershell
Get-ComputerInfo -Property "HyperVRequirementVMMonitorModeExtensions"
```
Should return `True`. If not, enable virtualization in BIOS.

## 🚀 Quick Start - Windows 11

### Step 1: Install Docker Desktop for Windows

#### Option A: Download from Docker Website
1. Download Docker Desktop from: https://www.docker.com/products/docker-desktop/
2. Run the installer
3. **IMPORTANT**: During installation, ensure "Use WSL 2 instead of Hyper-V" is selected
4. Restart your computer when prompted

#### Option B: Using winget (Windows Package Manager)
Open PowerShell as Administrator:
```powershell
winget install Docker.DockerDesktop
```

### Step 2: Configure Docker Desktop
1. Launch Docker Desktop from Start Menu
2. Wait for Docker to start (you'll see a whale icon in system tray)
3. Go to Settings (gear icon) → General
   - ✅ Use the WSL 2 based engine
   - ✅ Start Docker Desktop when you log in (optional)
4. Go to Settings → Resources → WSL Integration
   - ✅ Enable integration with your default WSL distro

### Step 3: Run the App

Open PowerShell (regular user, not admin) and navigate to your project:
```powershell
cd C:\Users\vdman\Downloads\projects\youtube-video-chat-app
```

Then run:
```powershell
# First time - build and start
docker-compose up --build

# Subsequent runs
docker-compose up
```

### Step 4: Access Your App
Open your browser and go to: **http://localhost:4000**

That's it! 🎉

## 🛠️ PowerShell Commands for Windows

### Basic Operations
```powershell
# Start the app (see logs)
docker-compose up

# Start the app (background)
docker-compose up -d

# Stop the app
docker-compose down

# View logs
docker-compose logs -f

# Restart after code changes
docker-compose restart web

# Stop all containers
docker-compose stop
```

### Troubleshooting Commands
```powershell
# Rebuild containers
docker-compose down
docker-compose up --build

# Clean everything (nuclear option)
docker-compose down -v --remove-orphans
docker system prune -a

# Access Elixir console
docker-compose exec web iex -S mix

# Run database migrations
docker-compose exec web mix ecto.migrate

# Reset database
docker-compose exec web mix ecto.drop
docker-compose exec web mix ecto.create
docker-compose exec web mix ecto.migrate
```

## 🔧 Windows-Specific Troubleshooting

### "Docker Desktop - WSL 2 installation is incomplete"
1. Open PowerShell as Administrator
2. Run these commands:
```powershell
wsl --set-default-version 2
wsl --install
wsl --update
```
3. Restart your computer
4. Start Docker Desktop again

### "The Docker daemon is not running"
1. Check if Docker Desktop is running (look for whale icon in system tray)
2. If not, start Docker Desktop from Start Menu
3. Wait 30-60 seconds for it to fully start
4. Try your command again

### Port 4000 Already in Use
Check what's using port 4000:
```powershell
netstat -ano | findstr :4000
```

Kill the process (replace PID with the actual number):
```powershell
taskkill /PID <PID> /F
```

Or change the port in `docker-compose.yml`:
```yaml
ports:
  - "4001:4000"  # Use localhost:4001 instead
```

### Slow Performance on Windows
1. Open Docker Desktop Settings
2. Go to Resources → Advanced
3. Increase:
   - CPUs: 4 or more
   - Memory: 8GB or more
4. Go to Resources → WSL Integration
5. Ensure your WSL distro is enabled

### File Change Detection Not Working
This is a known issue with Docker on Windows. Solutions:

1. **Use polling** (already configured in this project)
2. **Edit files within WSL** instead of Windows
3. **Restart the web container** after changes:
```powershell
docker-compose restart web
```

### Permission Errors
If you see permission errors, try:
1. Run PowerShell as regular user (NOT as Administrator)
2. Ensure files aren't read-only:
```powershell
attrib -R *.* /S
```

## 💡 Windows Tips

### Use Windows Terminal
Install Windows Terminal from Microsoft Store for better experience:
- Multiple tabs
- Better colors
- Split panes
- Better copy/paste

### File Paths
Windows paths work in docker-compose:
- Windows: `C:\Users\vdman\projects`
- Docker sees: `/c/Users/vdman/projects`

### Line Endings
If you get errors about line endings:
1. Configure Git:
```powershell
git config --global core.autocrlf true
```
2. Or use `.gitattributes` file (already included)

## 🚀 Quick PowerShell Script

Save this as `start-docker-windows.ps1`:
```powershell
Write-Host "🐳 Starting YouTube Watch Party App..." -ForegroundColor Cyan

# Check if Docker is running
$dockerRunning = docker info 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is not running. Starting Docker Desktop..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    
    Write-Host "Waiting for Docker to start..." -ForegroundColor Yellow
    $timeout = 60
    $counter = 0
    while ($counter -lt $timeout) {
        Start-Sleep -Seconds 2
        $counter += 2
        $dockerRunning = docker info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Docker is running!" -ForegroundColor Green
            break
        }
        Write-Host "." -NoNewline
    }
    if ($counter -ge $timeout) {
        Write-Host "`n❌ Docker failed to start. Please start Docker Desktop manually." -ForegroundColor Red
        exit 1
    }
}

# Navigate to project directory
Set-Location "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"

# Stop any existing containers
Write-Host "`nStopping any existing containers..." -ForegroundColor Yellow
docker-compose down 2>$null

# Start the app
Write-Host "`n🚀 Starting the app..." -ForegroundColor Green
docker-compose up --build
```

Run it with:
```powershell
.\start-docker-windows.ps1
```

## 📝 Environment Variables (Windows)

If you need to set environment variables, create a `.env` file:
```env
DATABASE_URL=postgresql://postgres:postgres@db/youtube_video_chat_app_dev
PHX_HOST=localhost
SECRET_KEY_BASE=your-secret-key-here
MIX_ENV=dev
```

## 🎯 Next Steps

1. **Create a room** - Click "Create New Room"
2. **Share the link** - Send to friends
3. **Add YouTube videos** - Paste URLs in the queue
4. **Start chatting** - Messages float across the video!

## 🆘 Need More Help?

- Docker Desktop Documentation: https://docs.docker.com/desktop/windows/
- WSL 2 Documentation: https://docs.microsoft.com/en-us/windows/wsl/
- Phoenix Framework: https://www.phoenixframework.org/

## 📌 Quick Reference

| Action | Command |
|--------|---------|
| Start app | `docker-compose up` |
| Stop app | `Ctrl+C` then `docker-compose down` |
| Run in background | `docker-compose up -d` |
| View logs | `docker-compose logs -f` |
| Rebuild | `docker-compose up --build` |
| Access at | http://localhost:4000 |
