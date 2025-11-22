@echo off
REM Package the Windows app for distribution
REM This creates a zip file with all necessary files

echo ========================================
echo Packaging Windows App for Distribution
echo ========================================
echo.

set BUILD_DIR=build\windows\x64\runner\Release
set PACKAGE_NAME=bvo_windows_v1.0.0
set OUTPUT_DIR=dist\%PACKAGE_NAME%

REM Check if build exists
if not exist "%BUILD_DIR%\DongSonWord.exe" (
    echo ERROR: Build not found!
    echo Please run build_windows.bat first
    pause
    exit /b 1
)

echo [1/3] Creating output directory...
if exist "%OUTPUT_DIR%" rmdir /s /q "%OUTPUT_DIR%"
mkdir "%OUTPUT_DIR%"

echo.
echo [2/3] Copying files...
xcopy /E /I /Y "%BUILD_DIR%\*" "%OUTPUT_DIR%"

echo.
echo [3/3] Creating README for users...
(
echo ========================================
echo BVO - Dong Son Word
echo ========================================
echo.
echo Hướng dẫn cài đặt:
echo.
echo 1. Giải nén file này vào thư mục bất kỳ
echo 2. Chạy file DongSonWord.exe
echo.
echo ========================================
echo Yêu cầu hệ thống:
echo ========================================
echo.
echo - Windows 10 trở lên
echo - Visual C++ Redistributable 2015-2022
echo.
echo Nếu gặp lỗi khi chạy, vui lòng cài đặt:
echo Visual C++ Redistributable từ Microsoft:
echo https://aka.ms/vs/17/release/vc_redist.x64.exe
echo.
echo ========================================
echo Lưu ý:
echo ========================================
echo.
echo - Ứng dụng sẽ lưu dữ liệu trong thư mục:
echo   %APPDATA%\bvo\
echo.
echo - Không cần cài đặt, chỉ cần chạy file exe
echo.
) > "%OUTPUT_DIR%\README.txt"

echo.
echo ========================================
echo Packaging completed!
echo ========================================
echo.
echo Output directory: %OUTPUT_DIR%
echo.
echo You can now zip this folder and send it to users.
echo.
pause

