# Universal build preparation script
# Automatically detects target platform and prepares environment
# Usage: .\prepare_build.ps1 [android|windows]

param(
    [Parameter(Position=0)]
    [ValidateSet("android", "windows", "auto")]
    [string]$Platform = "auto"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build Preparation Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Auto-detect platform if not specified
if ($Platform -eq "auto") {
    # Check if there's a recent Android build
    $androidBuildExists = Test-Path "build\app\outputs"
    $windowsBuildExists = Test-Path "build\windows"
    
    if ($androidBuildExists -and -not $windowsBuildExists) {
        $Platform = "android"
        Write-Host "Auto-detected: Android (recent build found)" -ForegroundColor Yellow
    } elseif ($windowsBuildExists -and -not $androidBuildExists) {
        $Platform = "windows"
        Write-Host "Auto-detected: Windows (recent build found)" -ForegroundColor Yellow
    } else {
        # Default to current platform or ask user
        Write-Host "Platform not specified. Use: .\prepare_build.ps1 [android|windows]" -ForegroundColor Yellow
        Write-Host "Assuming Windows (use -Platform android for Android)" -ForegroundColor Gray
        $Platform = "windows"
    }
}

Write-Host "Target Platform: $Platform" -ForegroundColor Green
Write-Host ""

# Common cleanup
Write-Host "[1/4] Cleaning Flutter cache..." -ForegroundColor Yellow
flutter clean | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: flutter clean had issues, continuing..." -ForegroundColor Yellow
}

# Platform-specific cleanup
if ($Platform -eq "windows") {
    Write-Host "[2/4] Cleaning Windows-specific build artifacts..." -ForegroundColor Yellow
    
    $windowsDirs = @(
        "build\windows",
        "windows\build",
        "windows\flutter\ephemeral"
    )
    
    foreach ($dir in $windowsDirs) {
        if (Test-Path $dir) {
            Write-Host "  Removing: $dir" -ForegroundColor Gray
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Remove CMake cache files
    $cmakeCacheFiles = Get-ChildItem -Path "." -Recurse -Filter "CMakeCache.txt" -ErrorAction SilentlyContinue | 
        Where-Object { $_.FullName -like "*windows*" }
    foreach ($file in $cmakeCacheFiles) {
        Write-Host "  Removing CMake cache: $($file.Name)" -ForegroundColor Gray
        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
    }
    
} elseif ($Platform -eq "android") {
    Write-Host "[2/4] Cleaning Android-specific build artifacts..." -ForegroundColor Yellow
    
    $androidDirs = @(
        "build\app",
        "android\build",
        "android\.gradle",
        "android\app\build"
    )
    
    foreach ($dir in $androidDirs) {
        if (Test-Path $dir) {
            Write-Host "  Removing: $dir" -ForegroundColor Gray
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Get dependencies
Write-Host "[3/4] Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: flutter pub get failed!" -ForegroundColor Red
    exit 1
}

# Platform-specific fixes
if ($Platform -eq "windows") {
    Write-Host "[4/4] Fixing Windows-specific issues..." -ForegroundColor Yellow
    
    # Fix flutter_tts plugin
    if (Test-Path ".\fix_flutter_tts.ps1") {
        Write-Host "  Fixing flutter_tts plugin..." -ForegroundColor Gray
        & ".\fix_flutter_tts.ps1" | Out-Null
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Windows build ready!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run with:" -ForegroundColor Cyan
    Write-Host "  .\run_windows.ps1" -ForegroundColor White
    Write-Host "  or" -ForegroundColor Gray
    Write-Host "  flutter run -d windows" -ForegroundColor White
    Write-Host ""
    
} elseif ($Platform -eq "android") {
    Write-Host "[4/4] Android build ready!" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Android build ready!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run with:" -ForegroundColor Cyan
    Write-Host "  flutter run -d android" -ForegroundColor White
    Write-Host "  or" -ForegroundColor Gray
    Write-Host "  flutter build apk" -ForegroundColor White
    Write-Host ""
}

