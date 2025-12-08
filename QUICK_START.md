# Quick Start Guide - Build cho Android và Windows

## Chuyển đổi giữa Android và Windows

### Từ Android → Windows:
```powershell
.\prepare_build.ps1 windows
.\run_windows.ps1
```

### Từ Windows → Android:
```powershell
.\prepare_build.ps1 android
flutter run -d android
```

## Scripts có sẵn

### `prepare_build.ps1` - Chuẩn bị build (Khuyến nghị)
- Tự động detect platform
- Clean cache và build artifacts
- Fix các vấn đề platform-specific
- Lấy dependencies

**Usage:**
```powershell
.\prepare_build.ps1 windows    # Chuẩn bị cho Windows
.\prepare_build.ps1 android    # Chuẩn bị cho Android
.\prepare_build.ps1 auto       # Tự động detect (mặc định)
```

### `run_windows.ps1` - Build và chạy Windows
- Tự động setup Visual Studio environment
- Tự động fix flutter_tts plugin
- Tự động detect và prepare nếu cần
- Chạy app trên Windows

**Usage:**
```powershell
.\run_windows.ps1
```

### `clean_windows_build.ps1` - Cleanup Windows build
- Clean Flutter cache
- Xóa Windows build directories
- Xóa CMake cache
- Fix flutter_tts

**Usage:**
```powershell
.\clean_windows_build.ps1
```

## Workflow khuyến nghị

### Lần đầu build Windows:
```powershell
.\prepare_build.ps1 windows
.\run_windows.ps1
```

### Sau khi build Android, chuyển sang Windows:
```powershell
.\prepare_build.ps1 windows
.\run_windows.ps1
```

### Sau khi build Windows, chuyển sang Android:
```powershell
.\prepare_build.ps1 android
flutter run -d android
```

## Troubleshooting

### Lỗi khi chuyển platform:
→ Chạy `.\prepare_build.ps1 [platform]` trước khi build

### Lỗi CMake/Windows build:
→ Chạy `.\clean_windows_build.ps1` rồi build lại

### Lỗi flutter_tts:
→ Script tự động fix, hoặc chạy `.\fix_flutter_tts.ps1`

