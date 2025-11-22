# Hướng dẫn Build Windows cho Dự án Flutter

## Yêu cầu

- Flutter 3.38.1 (hoặc mới hơn)
- Visual Studio 2022 (Community/Professional/Enterprise)
- Windows SDK và C++ build tools

## Cách Build

### Cách 1: Sử dụng Script Tự động (Khuyến nghị)

```powershell
.\run_windows.ps1
```

Hoặc:

```cmd
run_windows.bat
```

Script này sẽ:
1. Tự động tìm và cấu hình Visual Studio 2022
2. Sửa lỗi CMake của plugin `flutter_tts` (nếu cần)
3. Chạy Flutter build với môi trường đã cấu hình

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

## Sau khi Clean Build

Sau khi chạy `flutter clean`, bạn cần:

1. **Chạy lại script fix** (nếu dùng flutter_tts):
   ```powershell
   .\fix_flutter_tts.ps1
   ```

2. **Hoặc dùng script tự động**:
   ```powershell
   .\run_windows.ps1
   ```
   (Script này tự động fix trước khi build)

## Lưu ý Quan Trọng

### File KHÔNG nên commit:
- `windows/flutter/ephemeral/` - Flutter tự động generate
- `windows/build/` - Build artifacts
- `build/windows/` - Build output
- `.fvmrc` - Đã xóa, không dùng FVM nữa

### File NÊN commit:
- `run_windows.ps1` - Script build tự động
- `run_windows.bat` - Script build tự động (batch)
- `fix_flutter_tts.ps1` - Script fix plugin flutter_tts
- `fix_flutter_cmake.ps1` - Script fix CMake (nếu cần)
- `windows/CMakeLists.txt` - CMake configuration
- `.vscode/settings.json` - VS Code settings (đã xóa FVM path)

## Troubleshooting

### Lỗi: "Visual Studio 16 2019 could not be found"
- Chạy `.\run_windows.ps1` để tự động cấu hình Visual Studio 2022
- Hoặc set environment: `$env:CMAKE_GENERATOR = "Visual Studio 17 2022"`

### Lỗi: "flutter_tts CMake parse error"
- Chạy `.\fix_flutter_tts.ps1` để tự động sửa
- Hoặc chạy `.\run_windows.ps1` (tự động fix)

### Lỗi: "MSB3073: cmake_install.cmake exited with code 1"
- Chạy `flutter clean` để xóa cache cũ
- Build lại với `.\run_windows.ps1`

## Kiểm tra Môi trường

```powershell
# Kiểm tra Flutter version
flutter --version

# Kiểm tra Visual Studio
& "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" && where cl
```

