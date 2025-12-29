# Auto-fix CMake errors before building
# This script ensures flutter_tts CMakeLists.txt is fixed before each build
# It's automatically called by run_windows.ps1

$ErrorActionPreference = "Continue"

Write-Host "Pre-build CMake fix check..." -ForegroundColor Cyan

# Step 1: Ensure dependencies are fetched
if (-not (Test-Path "windows\flutter\ephemeral")) {
    Write-Host "Running flutter pub get to generate ephemeral folder..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: flutter pub get failed!" -ForegroundColor Red
        exit 1
    }
    # Wait for ephemeral folder to be fully created
    Start-Sleep -Seconds 1
}

# Step 2: Fix flutter_tts
if (Test-Path ".\fix_flutter_tts.ps1") {
    Write-Host "Running fix_flutter_tts.ps1..." -ForegroundColor Yellow
    & ".\fix_flutter_tts.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: fix_flutter_tts.ps1 had issues!" -ForegroundColor Yellow
    }
} else {
    Write-Host "Warning: fix_flutter_tts.ps1 not found!" -ForegroundColor Yellow
}

Write-Host "Pre-build check complete!" -ForegroundColor Green

