# Hướng dẫn Build Windows Executable

## Yêu cầu

1. **Flutter SDK** đã được cài đặt và cấu hình
2. **Visual Studio 2022** với các components:
   - Desktop development with C++
   - Windows 10/11 SDK
3. **Git** (thường đã có khi cài Flutter)

## Cách Build

### Cách 1: Sử dụng Script (Khuyến nghị)

**Nếu đang chuyển từ Android:**
```powershell
.\prepare_build.ps1 windows
flutter build windows --release
```

**Hoặc dùng script build:**
```batch
build_windows.bat
```

**Hoặc PowerShell:**
```powershell
.\prepare_build.ps1 windows
flutter build windows --release
```

3. Đợi build hoàn tất (có thể mất 5-10 phút lần đầu)
4. File exe sẽ nằm tại: `build\windows\x64\runner\Release\DongSonWord.exe`

### Cách 2: Build thủ công

```powershell
.\prepare_build.ps1 windows
flutter build windows --release
```

## Package để gửi cho người khác

### Sử dụng Script (Khuyến nghị)

1. Sau khi build xong, chạy:
   ```batch
   package_for_distribution.bat
   ```
2. Thư mục `dist\bvo_windows_v1.0.0` sẽ chứa tất cả file cần thiết
3. Zip thư mục này và gửi cho người dùng

### Package thủ công

1. Copy toàn bộ thư mục `build\windows\x64\runner\Release` vào một thư mục mới
2. Thêm file README.txt với hướng dẫn
3. Zip lại và gửi

## Yêu cầu cho máy người dùng

### Bắt buộc:
- **Windows 10** trở lên (64-bit)
- **Visual C++ Redistributable 2015-2022** (x64)

### Cài Visual C++ Redistributable:

**Cách 1: Tự động (Khuyến nghị)**
- Người dùng tải và cài từ Microsoft:
  https://aka.ms/vs/17/release/vc_redist.x64.exe

**Cách 2: Kiểm tra xem đã có chưa**
- Mở "Add or Remove Programs" (Settings > Apps)
- Tìm "Microsoft Visual C++ 2015-2022 Redistributable (x64)"
- Nếu có rồi thì không cần cài thêm

### Kiểm tra nhanh:
```batch
# Chạy trong Command Prompt
wmic product get name | findstr "Visual C++"
```

## Cấu trúc thư mục Release

Khi build xong, thư mục Release sẽ chứa:
```
Release/
├── bvo.exe              # File chính cần chạy
├── data/                # Thư mục dữ liệu
├── flutter_windows.dll  # Flutter runtime
├── *.dll                # Các thư viện cần thiết
└── ...                  # Các file khác
```

**LƯU Ý:** Phải gửi TOÀN BỘ thư mục Release, không chỉ file exe!

## Troubleshooting

### Lỗi: "Unable to find Visual Studio"
- Cài Visual Studio 2022 với component "Desktop development with C++"
- Hoặc cài Visual Studio Build Tools

### Lỗi: "CMake not found"
- Cài CMake từ: https://cmake.org/download/
- Hoặc cài qua Visual Studio Installer

### Lỗi khi chạy exe: "VCRUNTIME140.dll is missing"
- Người dùng cần cài Visual C++ Redistributable
- Link: https://aka.ms/vs/17/release/vc_redist.x64.exe

### Lỗi khi chạy exe: "The application was unable to start correctly"
- Kiểm tra Windows version (cần Windows 10+)
- Kiểm tra Visual C++ Redistributable đã cài chưa
- Thử chạy với quyền Administrator

## Tối ưu kích thước

Nếu muốn giảm kích thước file:
1. Build với `--split-debug-info` (không khuyến nghị cho release)
2. Sử dụng UPX để nén exe (có thể gây lỗi antivirus)

## Kiểm tra Build

Sau khi build, test trên máy khác (không có Flutter/Visual Studio):
1. Copy toàn bộ thư mục Release
2. Chạy bvo.exe
3. Kiểm tra mọi chức năng hoạt động

## Gửi cho người dùng

1. Zip thư mục Release (hoặc dùng script package)
2. Upload lên Google Drive / OneDrive / Dropbox
3. Gửi link cho người dùng
4. Nhắc họ cài Visual C++ Redistributable nếu cần

