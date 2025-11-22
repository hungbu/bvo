# Fix Flutter CMake to use Visual Studio 2026
# This script patches Flutter's tool backend to use the correct generator

$ErrorActionPreference = "Stop"

$flutterRoot = "C:\flutter\flutter"
$toolBackend = "$flutterRoot\packages\flutter_tools\bin\tool_backend.bat"

if (-not (Test-Path $toolBackend)) {
    Write-Host "Error: Flutter tool backend not found at $toolBackend" -ForegroundColor Red
    exit 1
}

Write-Host "Backing up tool_backend.bat..." -ForegroundColor Yellow
Copy-Item $toolBackend "$toolBackend.backup" -Force

Write-Host "Checking tool_backend.bat for CMake calls..." -ForegroundColor Cyan
$content = Get-Content $toolBackend -Raw

# Check if it already has our patch
if ($content -match "Visual Studio 18 2025") {
    Write-Host "Tool backend already patched!" -ForegroundColor Green
    exit 0
}

# Try to replace Visual Studio 16 2019 with Visual Studio 18 2025
if ($content -match "Visual Studio 16 2019") {
    Write-Host "Found Visual Studio 16 2019, replacing with Visual Studio 18 2025..." -ForegroundColor Yellow
    $content = $content -replace "Visual Studio 16 2019", "Visual Studio 18 2025"
    Set-Content $toolBackend $content -NoNewline
    Write-Host "Patched successfully!" -ForegroundColor Green
} else {
    Write-Host "Warning: Could not find 'Visual Studio 16 2019' in tool_backend.bat" -ForegroundColor Yellow
    Write-Host "Flutter may be detecting Visual Studio differently." -ForegroundColor Yellow
    Write-Host "`nTrying alternative approach: Setting environment variables globally..." -ForegroundColor Cyan
    
    # Set user-level environment variables
    [System.Environment]::SetEnvironmentVariable("CMAKE_GENERATOR", "Visual Studio 18 2025", "User")
    [System.Environment]::SetEnvironmentVariable("CMAKE_GENERATOR_PLATFORM", "x64", "User")
    
    Write-Host "Set CMAKE_GENERATOR and CMAKE_GENERATOR_PLATFORM as user environment variables." -ForegroundColor Green
    Write-Host "You may need to restart your terminal for these to take effect." -ForegroundColor Yellow
}

Write-Host "`nDone! Try running Flutter again." -ForegroundColor Green

