# Windows Docker Troubleshooting Script
# Run this if you're having issues with Docker on Windows

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "     🔧 DOCKER TROUBLESHOOTING FOR WINDOWS     " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Function to run command and show result
function Test-Command {
    param(
        [string]$Description,
        [scriptblock]$Command
    )
    
    Write-Host "$Description" -ForegroundColor Yellow -NoNewline
    try {
        $result = & $Command 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " ✅" -ForegroundColor Green
            if ($result) {
                Write-Host "  → $result" -ForegroundColor Gray
            }
        } else {
            Write-Host " ❌" -ForegroundColor Red
        }
    }
    catch {
        Write-Host " ❌" -ForegroundColor Red
        Write-Host "  → Error: $_" -ForegroundColor Red
    }
}

# System Information
Write-Host "SYSTEM INFORMATION:" -ForegroundColor White
Write-Host "===================" -ForegroundColor White

# Windows Version
$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Host "Windows Version: $($osInfo.Caption) - $($osInfo.Version)" -ForegroundColor Cyan

# Check Virtualization
Write-Host ""
Write-Host "VIRTUALIZATION CHECK:" -ForegroundColor White
Write-Host "=====================" -ForegroundColor White

$hyperV = Get-ComputerInfo -Property "HyperVRequirementVMMonitorModeExtensions"
if ($hyperV.HyperVRequirementVMMonitorModeExtensions) {
    Write-Host "Virtualization: ✅ Enabled" -ForegroundColor Green
} else {
    Write-Host "Virtualization: ❌ Disabled (Enable in BIOS)" -ForegroundColor Red
}

# Check WSL
Write-Host ""
Write-Host "WSL CHECK:" -ForegroundColor White
Write-Host "==========" -ForegroundColor White

Test-Command "WSL Installed:" { wsl --version }

$wslDistros = wsl --list --verbose 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "WSL Distributions:" -ForegroundColor Cyan
    Write-Host $wslDistros
} else {
    Write-Host "No WSL distributions found. Install with: wsl --install" -ForegroundColor Yellow
}

# Docker Checks
Write-Host ""
Write-Host "DOCKER CHECK:" -ForegroundColor White
Write-Host "=============" -ForegroundColor White

Test-Command "Docker Installed:" { docker --version }
Test-Command "Docker Compose:" { docker-compose --version }
Test-Command "Docker Running:" { docker info }

# Check Docker service
$dockerService = Get-Service -Name "Docker Desktop Service" -ErrorAction SilentlyContinue
if ($dockerService) {
    Write-Host "Docker Service Status: $($dockerService.Status)" -ForegroundColor Cyan
} else {
    Write-Host "Docker Desktop Service: Not found" -ForegroundColor Yellow
}

# Port Check
Write-Host ""
Write-Host "PORT CHECK:" -ForegroundColor White
Write-Host "===========" -ForegroundColor White

$port4000 = Get-NetTCPConnection -LocalPort 4000 -ErrorAction SilentlyContinue
if ($port4000) {
    Write-Host "Port 4000: ⚠️ IN USE" -ForegroundColor Yellow
    $process = Get-Process -Id $port4000.OwningProcess
    Write-Host "  → Used by: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Gray
} else {
    Write-Host "Port 4000: ✅ Available" -ForegroundColor Green
}

# Docker Resources
Write-Host ""
Write-Host "DOCKER RESOURCES:" -ForegroundColor White
Write-Host "=================" -ForegroundColor White

if (docker info 2>$null) {
    $containers = docker ps -a --format "table {{.Names}}\t{{.Status}}" 2>$null
    Write-Host "Docker Containers:" -ForegroundColor Cyan
    if ($containers) {
        Write-Host $containers
    } else {
        Write-Host "  No containers found" -ForegroundColor Gray
    }
    
    Write-Host ""
    $images = docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>$null
    Write-Host "Docker Images:" -ForegroundColor Cyan
    if ($images) {
        Write-Host $images
    } else {
        Write-Host "  No images found" -ForegroundColor Gray
    }
}

# Common Fixes
Write-Host ""
Write-Host "================================================" -ForegroundColor Yellow
Write-Host "              COMMON FIXES                     " -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. If Docker is not running:" -ForegroundColor White
Write-Host "   → Start Docker Desktop from Start Menu" -ForegroundColor Gray
Write-Host ""

Write-Host "2. If WSL is not installed:" -ForegroundColor White
Write-Host "   → Run as Admin: wsl --install" -ForegroundColor Gray
Write-Host "   → Restart computer" -ForegroundColor Gray
Write-Host ""

Write-Host "3. If port 4000 is in use:" -ForegroundColor White
Write-Host "   → Stop the process using it, or" -ForegroundColor Gray
Write-Host "   → Change port in docker-compose.yml" -ForegroundColor Gray
Write-Host ""

Write-Host "4. If containers won't start:" -ForegroundColor White
Write-Host "   → docker-compose down -v" -ForegroundColor Gray
Write-Host "   → docker-compose up --build" -ForegroundColor Gray
Write-Host ""

Write-Host "5. For performance issues:" -ForegroundColor White
Write-Host "   → Docker Desktop Settings → Resources" -ForegroundColor Gray
Write-Host "   → Increase CPU and Memory allocation" -ForegroundColor Gray
Write-Host ""

# Quick Actions
Write-Host "================================================" -ForegroundColor Green
Write-Host "              QUICK ACTIONS                    " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Would you like to perform any quick fixes? (y/n)" -ForegroundColor Cyan
$response = Read-Host

if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host ""
    Write-Host "Select an option:" -ForegroundColor Yellow
    Write-Host "1. Clean all Docker containers and images" -ForegroundColor White
    Write-Host "2. Reset Docker to factory defaults" -ForegroundColor White
    Write-Host "3. Install/Update WSL" -ForegroundColor White
    Write-Host "4. Start Docker Desktop" -ForegroundColor White
    Write-Host "5. Exit" -ForegroundColor White
    
    $choice = Read-Host "Enter choice (1-5)"
    
    switch ($choice) {
        "1" {
            Write-Host "Cleaning Docker..." -ForegroundColor Yellow
            docker stop $(docker ps -aq) 2>$null
            docker rm $(docker ps -aq) 2>$null
            docker system prune -a -f
            Write-Host "✅ Docker cleaned!" -ForegroundColor Green
        }
        "2" {
            Write-Host "This will reset Docker to factory defaults." -ForegroundColor Red
            Write-Host "Are you sure? (y/n)" -ForegroundColor Yellow
            $confirm = Read-Host
            if ($confirm -eq 'y') {
                & "C:\Program Files\Docker\Docker\Docker Desktop.exe" factory-reset
            }
        }
        "3" {
            Write-Host "Installing/Updating WSL..." -ForegroundColor Yellow
            Write-Host "This requires Administrator privileges." -ForegroundColor Yellow
            Start-Process powershell -Verb RunAs -ArgumentList "wsl --install; wsl --update"
        }
        "4" {
            Write-Host "Starting Docker Desktop..." -ForegroundColor Yellow
            Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        }
        "5" {
            Write-Host "Exiting..." -ForegroundColor Gray
        }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "         Troubleshooting Complete!             " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

Read-Host "Press Enter to exit"
