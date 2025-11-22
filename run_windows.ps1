# PowerShell wrapper script to run Flutter Windows with Visual Studio 2026
# Usage: .\run_windows.ps1

$ErrorActionPreference = "Stop"

# Find Visual Studio 2022
$VS2022Paths = @(
    "C:\Program Files\Microsoft Visual Studio\2022\Community",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
)

$VS2022Path = $null
foreach ($path in $VS2022Paths) {
    if (Test-Path $path) {
        $VS2022Path = $path
        break
    }
}

if (-not $VS2022Path) {
    Write-Host "Error: Visual Studio 2022 not found in standard locations" -ForegroundColor Red
    Write-Host "Searched in:" -ForegroundColor Yellow
    foreach ($path in $VS2022Paths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
    Write-Host "Please verify Visual Studio 2022 installation." -ForegroundColor Red
    exit 1
}

# Set CMake generator environment variables for Visual Studio 2022
$env:CMAKE_GENERATOR = "Visual Studio 17 2022"
$env:CMAKE_GENERATOR_PLATFORM = "x64"

# Import Visual Studio environment
$vcvarsPath = "$VS2022Path\VC\Auxiliary\Build\vcvars64.bat"
if (Test-Path $vcvarsPath) {
    # Run vcvars64.bat and capture environment variables
    cmd /c "`"$vcvarsPath`" && set" | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
            Set-Item -Path "env:$($matches[1])" -Value $matches[2]
        }
    }
}

# Add Visual Studio tools to PATH
$VSTools = "$VS2022Path\Common7\Tools"
$env:PATH = "$VSTools;$VS2022Path\VC\Tools\MSVC\*\bin\Hostx64\x64;$env:PATH"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Visual Studio 2022 Environment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VS Path: $VS2022Path" -ForegroundColor Green
Write-Host "CMake Generator: $env:CMAKE_GENERATOR" -ForegroundColor Green
Write-Host "Platform: $env:CMAKE_GENERATOR_PLATFORM" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Fix flutter_tts CMakeLists.txt if needed
Write-Host "Checking flutter_tts plugin configuration..." -ForegroundColor Cyan
if (Test-Path ".\fix_flutter_tts.ps1") {
    & ".\fix_flutter_tts.ps1"
}

# Fix flutter_tts CMakeLists.txt if needed
Write-Host "Checking flutter_tts plugin configuration..." -ForegroundColor Cyan
if (Test-Path ".\fix_flutter_tts.ps1") {
    & ".\fix_flutter_tts.ps1"
}

# Now run Flutter with the configured environment
Write-Host "`nRunning Flutter..." -ForegroundColor Cyan

# Verify environment
Write-Host "Environment check:" -ForegroundColor Yellow
Write-Host "  CMAKE_GENERATOR: $env:CMAKE_GENERATOR" -ForegroundColor Gray
Write-Host "  CMAKE_GENERATOR_PLATFORM: $env:CMAKE_GENERATOR_PLATFORM" -ForegroundColor Gray
Write-Host ""

C:\flutter\flutter\bin\flutter.bat run -d windows

