# Hướng dẫn Build Windows cho Dự án Flutter

## Yêu cầu

- Flutter 3.38.1 (hoặc mới hơn)
- Visual Studio 2022 (Community/Professional/Enterprise)
- Windows SDK và C++ build tools

## Cách Build

### Cách 1: Sử dụng Script Tự động (Khuyến nghị)

**Khi chuyển từ Android sang Windows:**
```powershell
.\prepare_build.ps1 windows
.\run_windows.ps1
```

**Hoặc chỉ chạy run_windows.ps1** (tự động detect và prepare):
```powershell
.\run_windows.ps1
```

**Batch file:**
```cmd
run_windows.bat
```

Script này sẽ:
1. Tự động detect và cleanup build artifacts từ platform khác
2. Tự động tìm và cấu hình Visual Studio 2022
3. Sửa lỗi CMake của plugin `flutter_tts` (nếu cần)
4. Chạy Flutter build với môi trường đã cấu hình

### Cách 2: Build Thủ công

```powershell
# 1. Fix flutter_tts plugin (nếu cần)
.\fix_flutter_tts.ps1

# 2. Set environment variables
$env:CMAKE_GENERATOR = "Visual Studio 17 2022"
$env:CMAKE_GENERATOR_PLATFORM = "x64"

# 3. Run Flutter
flutter run -d windows
```

## Chuyển đổi giữa Android và Windows

### Từ Android sang Windows:
```powershell
.\prepare_build.ps1 windows
.\run_windows.ps1
```

### Từ Windows sang Android:
```powershell
.\prepare_build.ps1 android
flutter run -d android
```

### Script `prepare_build.ps1` tự động:
- Clean Flutter cache
- Xóa build artifacts của platform cũ
- Xóa CMake cache (cho Windows)
- Lấy lại dependencies
- Fix flutter_tts plugin (cho Windows)

**Lưu ý**: Script `run_windows.ps1` tự động detect và gọi `prepare_build.ps1` nếu cần.

## Lưu ý Quan Trọng

### File KHÔNG nên commit:
- `windows/flutter/ephemeral/` - Flutter tự động generate
- `windows/build/` - Build artifacts
- `build/windows/` - Build output
- `.fvmrc` - Đã xóa, không dùng FVM nữa

### File NÊN commit:
- `prepare_build.ps1` - Script chuẩn bị build (tự động detect platform)
- `run_windows.ps1` - Script build Windows tự động
- `run_windows.bat` - Script build Windows tự động (batch)
- `clean_windows_build.ps1` - Script cleanup Windows build
- `fix_flutter_tts.ps1` - Script fix plugin flutter_tts
- `windows/CMakeLists.txt` - CMake configuration

## Troubleshooting

### Lỗi: "Visual Studio 16 2019 could not be found"
- Chạy `.\run_windows.ps1` để tự động cấu hình Visual Studio 2022
- Hoặc set environment: `$env:CMAKE_GENERATOR = "Visual Studio 17 2022"`

### Lỗi: "flutter_tts CMake parse error"
- Chạy `.\fix_flutter_tts.ps1` để tự động sửa
- Hoặc chạy `.\run_windows.ps1` (tự động fix)

### Lỗi: "MSB3073: cmake_install.cmake exited with code 1"
- **Nguyên nhân**: Thường xảy ra sau khi chuyển giữa các platform (Android/Windows) hoặc cache bị lỗi
- **Giải pháp**:
  1. **Cách đơn giản nhất**: Chạy `.\prepare_build.ps1 windows` rồi `.\run_windows.ps1`
  2. Hoặc chạy script cleanup: `.\clean_windows_build.ps1`
  3. Hoặc thủ công:
     ```powershell
     flutter clean
     Remove-Item -Recurse -Force build\windows, windows\build, windows\flutter\ephemeral -ErrorAction SilentlyContinue
     flutter pub get
     .\fix_flutter_tts.ps1
     ```
  4. Build lại: `.\run_windows.ps1`

## Kiểm tra Môi trường

```powershell
# Kiểm tra Flutter version
flutter --version

# Kiểm tra Visual Studio
& "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" && where cl
```

