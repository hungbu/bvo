@echo off
REM Build script for Windows executable
REM This script builds a release version of the Flutter app for Windows

echo ========================================
echo Building Flutter App for Windows
echo ========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter and add it to your PATH
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo [1/4] Cleaning previous build...
flutter clean
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Flutter clean failed!
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo.
echo [2/4] Getting dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Flutter pub get failed!
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo.
echo [3/4] Building Windows release...
echo This may take several minutes...
echo.
flutter build windows --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo ERROR: Build failed!
    echo ========================================
    echo.
    echo Please check the error messages above.
    echo Common issues:
    echo - Visual Studio not installed or not configured
    echo - CMake not found
    echo - Missing dependencies
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo.
echo [4/4] Build completed successfully!
echo.
echo ========================================
echo Build Output Location:
echo ========================================
echo build\windows\x64\runner\Release\
echo.
echo The executable file is: DongSonWord.exe
echo.
echo ========================================
echo IMPORTANT: For distribution
echo ========================================
echo 1. Copy the entire 'Release' folder to distribute
echo 2. The user needs Visual C++ Redistributable 2015-2022
echo 3. Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
echo.
echo Press any key to exit...
pause >nul

