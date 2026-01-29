# YouTube Watch Party App - Docker Launcher for Windows
# This script starts Docker Desktop if needed and launches the app

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "     🐳 YOUTUBE WATCH PARTY APP LAUNCHER      " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Warn if running as Administrator (not recommended for Docker)
if (Test-Administrator) {
    Write-Host "⚠️  Warning: Running as Administrator is not recommended for Docker" -ForegroundColor Yellow
    Write-Host "   Please run this script as a regular user instead." -ForegroundColor Yellow
    Write-Host ""
}

# Check if Docker is installed
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker is installed: $dockerVersion" -ForegroundColor Green
    }
}
catch {
    Write-Host "❌ Docker is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Docker Desktop for Windows:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://www.docker.com/products/docker-desktop/" -ForegroundColor White
    Write-Host "2. Or install via winget:" -ForegroundColor White
    Write-Host "   winget install Docker.DockerDesktop" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if Docker daemon is running
Write-Host "Checking Docker status..." -ForegroundColor Yellow
$dockerRunning = docker info 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Desktop is not running. Starting it now..." -ForegroundColor Yellow
    
    # Try to find Docker Desktop executable
    $dockerPaths = @(
        "C:\Program Files\Docker\Docker\Docker Desktop.exe",
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    )
    
    $dockerExe = $null
    foreach ($path in $dockerPaths) {
        if (Test-Path $path) {
            $dockerExe = $path
            break
        }
    }
    
    if ($dockerExe) {
        Start-Process $dockerExe
        Write-Host "Waiting for Docker to start (this may take 30-60 seconds)..." -ForegroundColor Yellow
        
        $timeout = 90
        $counter = 0
        while ($counter -lt $timeout) {
            Start-Sleep -Seconds 3
            $counter += 3
            
            # Show progress
            Write-Host "." -NoNewline
            
            # Check if Docker is running
            $dockerRunning = docker info 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "✅ Docker is now running!" -ForegroundColor Green
                break
            }
        }
        
        if ($counter -ge $timeout) {
            Write-Host ""
            Write-Host "❌ Docker is taking too long to start." -ForegroundColor Red
            Write-Host "Please ensure Docker Desktop is running (look for the whale icon in system tray)" -ForegroundColor Yellow
            Write-Host "Then run this script again." -ForegroundColor Yellow
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
    else {
        Write-Host "❌ Could not find Docker Desktop executable." -ForegroundColor Red
        Write-Host "Please start Docker Desktop manually from the Start Menu." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
}
else {
    Write-Host "✅ Docker is running!" -ForegroundColor Green
}

# Navigate to project directory
$projectPath = "C:\Users\vdman\Downloads\projects\youtube-video-chat-app"
if (Test-Path $projectPath) {
    Set-Location $projectPath
    Write-Host "📁 Project directory: $projectPath" -ForegroundColor Cyan
}
else {
    Write-Host "❌ Project directory not found: $projectPath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if docker-compose.yml exists
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "❌ docker-compose.yml not found in current directory!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "🧹 Cleaning up any existing containers..." -ForegroundColor Yellow
docker-compose down 2>$null

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "     🚀 STARTING YOUTUBE WATCH PARTY APP       " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The app will be available at: http://localhost:4000" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
Write-Host ""

# Check if this is first run or if rebuild is needed
$buildNeeded = $false
if (-not (Test-Path "_build") -or -not (Test-Path "deps")) {
    Write-Host "🔨 First run detected. Building containers..." -ForegroundColor Yellow
    $buildNeeded = $true
}

# Start the application
if ($buildNeeded) {
    Write-Host "This may take 2-3 minutes for the first build..." -ForegroundColor Yellow
    docker-compose up --build
}
else {
    docker-compose up
}

# After app stops
Write-Host ""
Write-Host "================================================" -ForegroundColor Yellow
Write-Host "         Application stopped                   " -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Cleaning up containers..." -ForegroundColor Yellow
docker-compose down

Write-Host "✅ Done!" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
