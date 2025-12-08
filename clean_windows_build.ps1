# Script to clean Windows build cache and rebuild
# Use this when switching between platforms (Android/Windows) or after build errors

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cleaning Windows Build Cache" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Flutter clean
Write-Host "[1/5] Running flutter clean..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: flutter clean had issues, continuing..." -ForegroundColor Yellow
}

# Step 2: Remove Windows build directories
Write-Host "[2/5] Removing Windows build directories..." -ForegroundColor Yellow
$buildDirs = @(
    "build\windows",
    "windows\build",
    "windows\flutter\ephemeral"
)

foreach ($dir in $buildDirs) {
    if (Test-Path $dir) {
        Write-Host "  Removing: $dir" -ForegroundColor Gray
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Step 3: Remove CMake cache files
Write-Host "[3/5] Removing CMake cache files..." -ForegroundColor Yellow
$cmakeCacheFiles = Get-ChildItem -Path "." -Recurse -Filter "CMakeCache.txt" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -like "*windows*" }
foreach ($file in $cmakeCacheFiles) {
    Write-Host "  Removing: $($file.FullName)" -ForegroundColor Gray
    Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
}

# Step 4: Get dependencies
Write-Host "[4/5] Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: flutter pub get failed!" -ForegroundColor Red
    exit 1
}

# Step 5: Fix flutter_tts
Write-Host "[5/5] Fixing flutter_tts plugin..." -ForegroundColor Yellow
if (Test-Path ".\fix_flutter_tts.ps1") {
    & ".\fix_flutter_tts.ps1"
} else {
    Write-Host "  Warning: fix_flutter_tts.ps1 not found, skipping..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Cleanup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now run:" -ForegroundColor Cyan
Write-Host "  .\run_windows.ps1" -ForegroundColor White
Write-Host "  or" -ForegroundColor Gray
Write-Host "  flutter run -d windows" -ForegroundColor White
Write-Host ""


