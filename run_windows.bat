@echo off
REM Batch wrapper script to run Flutter Windows with Visual Studio 2022
REM Usage: run_windows.bat

setlocal

REM Find Visual Studio 2022
set "VS2022_PATH="
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community" (
    set "VS2022_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community"
) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional" (
    set "VS2022_PATH=C:\Program Files\Microsoft Visual Studio\2022\Professional"
) else if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise" (
    set "VS2022_PATH=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
)

REM Check if Visual Studio 2022 exists
if "%VS2022_PATH%"=="" (
    echo Error: Visual Studio 2022 not found in standard locations
    echo Searched in:
    echo   - C:\Program Files\Microsoft Visual Studio\2022\Community
    echo   - C:\Program Files\Microsoft Visual Studio\2022\Professional
    echo   - C:\Program Files\Microsoft Visual Studio\2022\Enterprise
    echo Please verify Visual Studio 2022 installation.
    exit /b 1
)

REM Set CMake generator environment variables for Visual Studio 2022
set "CMAKE_GENERATOR=Visual Studio 17 2022"
set "CMAKE_GENERATOR_PLATFORM=x64"

REM Set Visual Studio environment variables
if exist "%VS2022_PATH%\VC\Auxiliary\Build\vcvars64.bat" (
    call "%VS2022_PATH%\VC\Auxiliary\Build\vcvars64.bat"
)

REM Add Visual Studio tools to PATH
set "VS_TOOLS=%VS2022_PATH%\Common7\Tools"
set "PATH=%VS_TOOLS%;%VS2022_PATH%\VC\Tools\MSVC\*\bin\Hostx64\x64;%PATH%"

echo.
echo ========================================
echo Visual Studio 2022 Environment
echo ========================================
echo VS Path: %VS2022_PATH%
echo CMake Generator: %CMAKE_GENERATOR%
echo Platform: %CMAKE_GENERATOR_PLATFORM%
echo ========================================
echo.

REM Verify environment
echo Environment check:
echo   CMAKE_GENERATOR: %CMAKE_GENERATOR%
echo   CMAKE_GENERATOR_PLATFORM: %CMAKE_GENERATOR_PLATFORM%
echo.

REM Fix flutter_tts CMakeLists.txt if needed
echo Checking flutter_tts plugin configuration...
if exist "fix_flutter_tts.ps1" (
    powershell -ExecutionPolicy Bypass -File "fix_flutter_tts.ps1"
)

REM Now run Flutter with the configured environment
echo.
echo Running Flutter...
C:\flutter\flutter\bin\flutter.bat run -d windows

endlocal

