# Script to automatically fix flutter_tts CMakeLists.txt after Flutter regenerates it
# Run this after: flutter clean, flutter pub get, or when build fails

$ErrorActionPreference = "Stop"

$flutterTtsPath = "windows\flutter\ephemeral\.plugin_symlinks\flutter_tts\windows\CMakeLists.txt"

if (-not (Test-Path $flutterTtsPath)) {
    Write-Host "flutter_tts CMakeLists.txt not found. Plugin may not be installed." -ForegroundColor Yellow
    exit 0
}

Write-Host "Fixing flutter_tts CMakeLists.txt..." -ForegroundColor Cyan

$content = Get-Content $flutterTtsPath -Raw

# Check if already fixed
if ($content -match "find_program\(NUGET_EXE NAMES nuget nuget\.exe") {
    if ($content -match "ENV PATH") {
        Write-Host "flutter_tts CMakeLists.txt already fixed!" -ForegroundColor Green
        exit 0
    }
}

# Backup original
$backupPath = "$flutterTtsPath.backup"
Copy-Item $flutterTtsPath $backupPath -Force
Write-Host "Backed up original to: $backupPath" -ForegroundColor Gray

# Fix NuGet path search - replace the problematic find_program section
$nugetFix = @'
################ NuGet install begin ################
# Find NuGet executable in PATH or use system nuget
find_program(NUGET_EXE NAMES nuget nuget.exe
  PATHS
    "C:/Program Files (x86)/NuGet"
    "C:/Program Files/NuGet"
    "C:/soft/NuGet"
    "C:/soft"
    ENV PATH
)

if(NOT NUGET_EXE)
  # Try to download nuget.exe if not found
  set(NUGET_URL "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe")
  set(NUGET_DOWNLOAD_PATH "${CMAKE_CURRENT_BINARY_DIR}/nuget.exe")
  
  if(NOT EXISTS ${NUGET_DOWNLOAD_PATH})
    message(STATUS "Downloading NuGet.exe...")
    file(DOWNLOAD ${NUGET_URL} ${NUGET_DOWNLOAD_PATH} SHOW_PROGRESS)
  endif()
  
  set(NUGET_EXE ${NUGET_DOWNLOAD_PATH})
endif()

# Ensure packages directory exists
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/packages)

# Install Microsoft.Windows.CppWinRT package
execute_process(
  COMMAND ${NUGET_EXE} install "Microsoft.Windows.CppWinRT" 
    -Version 2.0.210503.1 
    -ExcludeVersion 
    -OutputDirectory ${CMAKE_BINARY_DIR}/packages
    -NonInteractive
  RESULT_VARIABLE NUGET_RESULT
  OUTPUT_QUIET
  ERROR_QUIET
)

if(NOT NUGET_RESULT EQUAL 0)
  message(WARNING "NuGet install failed, trying alternative method...")
  # Try without ExcludeVersion
  execute_process(
    COMMAND ${NUGET_EXE} install "Microsoft.Windows.CppWinRT" 
      -Version 2.0.210503.1 
      -OutputDirectory ${CMAKE_BINARY_DIR}/packages
      -NonInteractive
    RESULT_VARIABLE NUGET_RESULT2
  )
  
  if(NOT NUGET_RESULT2 EQUAL 0)
    message(FATAL_ERROR "Failed to install Microsoft.Windows.CppWinRT NuGet package. Please install NuGet and try again.")
  endif()
endif()

# Verify the package was installed
if(NOT EXISTS "${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.CppWinRT/build/native/Microsoft.Windows.CppWinRT.props")
  message(FATAL_ERROR "Microsoft.Windows.CppWinRT package not found at expected location: ${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.CppWinRT")
endif()

message(STATUS "Microsoft.Windows.CppWinRT package installed successfully")
################ NuGet install end ################
'@

# Find and replace the NuGet section - handle both "intall" typo and "install" correct spelling
$patterns = @(
    '(?s)################ NuGet intall begin ################.*?################ NuGet install end ################',
    '(?s)################ NuGet install begin ################.*?################ NuGet install end ################'
)

$found = $false
foreach ($pattern in $patterns) {
    if ($content -match $pattern) {
        $content = $content -replace $pattern, $nugetFix
        $found = $true
        break
    }
}

# Also check for corrupted execute_process with ARGS (syntax error)
if (-not $found -and $content -match 'ARGS install') {
    Write-Host "Detected corrupted NuGet section with syntax errors, fixing..." -ForegroundColor Yellow
    # Try to find and replace from "NuGet" to the next "NuGet" or end of problematic section
    $corruptedPattern = '(?s)################ NuGet.*?ARGS install.*?################ NuGet install end ################'
    if ($content -match $corruptedPattern) {
        $content = $content -replace $corruptedPattern, $nugetFix
        $found = $true
    } else {
        # More aggressive: find any section with "NuGet" and "ARGS" or malformed execute_process
        $corruptedPattern2 = '(?s)################ NuGet.*?execute_process.*?ARGS.*?################ NuGet install end ################'
        if ($content -match $corruptedPattern2) {
            $content = $content -replace $corruptedPattern2, $nugetFix
            $found = $true
        }
    }
}

if ($found) {
    Set-Content $flutterTtsPath $content -NoNewline
    Write-Host "Fixed flutter_tts CMakeLists.txt successfully!" -ForegroundColor Green
} else {
    Write-Host "Warning: Could not find NuGet section to replace. File may have different structure." -ForegroundColor Yellow
    Write-Host "The file may already be fixed or have a different format." -ForegroundColor Yellow
    Write-Host "You may need to manually check the file for syntax errors." -ForegroundColor Yellow
}

Write-Host "`nYou can now try building again: flutter run -d windows" -ForegroundColor Cyan

