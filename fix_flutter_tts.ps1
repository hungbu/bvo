# Script to automatically fix flutter_tts CMakeLists.txt after Flutter regenerates it
# Run this after: flutter clean, flutter pub get, or when build fails
# This script fixes common CMake syntax errors including missing parentheses

$ErrorActionPreference = "Stop"

# Try multiple possible paths for the CMakeLists.txt file
$possiblePaths = @(
    "windows\flutter\ephemeral\.plugin_symlinks\flutter_tts\windows\CMakeLists.txt",
    "flutter\ephemeral\.plugin_symlinks\flutter_tts\windows\CMakeLists.txt"
)

$flutterTtsPath = $null
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $flutterTtsPath = $path
        break
    }
}

if (-not $flutterTtsPath) {
    Write-Host "flutter_tts CMakeLists.txt not found. Plugin may not be installed or ephemeral folder not generated yet." -ForegroundColor Yellow
    Write-Host "Try running: flutter pub get" -ForegroundColor Cyan
    exit 0
}

Write-Host "Fixing flutter_tts CMakeLists.txt at: $flutterTtsPath" -ForegroundColor Cyan

$content = Get-Content $flutterTtsPath -Raw

# Check for syntax errors: missing closing parentheses
Write-Host "Checking for syntax errors..." -ForegroundColor Cyan
$openParens = ([regex]::Matches($content, '\(')).Count
$closeParens = ([regex]::Matches($content, '\)')).Count
$openBrackets = ([regex]::Matches($content, '\{')).Count
$closeBrackets = ([regex]::Matches($content, '\}')).Count

if ($openParens -ne $closeParens) {
    Write-Host "Warning: Unbalanced parentheses detected! Open: $openParens, Close: $closeParens" -ForegroundColor Yellow
    Write-Host "Attempting to fix by adding missing closing parentheses..." -ForegroundColor Yellow
    
    # Try to fix by finding incomplete function calls near the end of file
    # Common pattern: find_program(... without closing )
    if ($content -match '(?s)(find_program\([^)]*?)(\r?\n\s*ENV PATH\s*)(\r?\n)') {
        $content = $content -replace '(?s)(find_program\([^)]*?)(\r?\n\s*ENV PATH\s*)(\r?\n)', '$1$2)$3'
        Write-Host "Fixed missing closing parenthesis in find_program!" -ForegroundColor Green
    }
    
    # Check again
    $openParens = ([regex]::Matches($content, '\(')).Count
    $closeParens = ([regex]::Matches($content, '\)')).Count
    if ($openParens -ne $closeParens) {
        Write-Host "Warning: Still unbalanced. Manual review may be needed." -ForegroundColor Yellow
    }
}

if ($openBrackets -ne $closeBrackets) {
    Write-Host "Warning: Unbalanced brackets detected! Open: $openBrackets, Close: $closeBrackets" -ForegroundColor Yellow
}

# Check if already fixed (but continue to check for windowsapp.lib)
$nugetFixed = $false
if ($content -match "find_program\(NUGET_EXE NAMES nuget nuget\.exe") {
    if ($content -match "ENV PATH") {
        $nugetFixed = $true
        Write-Host "NuGet section already fixed!" -ForegroundColor Green
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

# Fix incomplete find_program calls (common source of missing parenthesis errors)
if ($content -match '(?s)find_program\([^)]*ENV PATH\s*\n(?!\))') {
    Write-Host "Fixing incomplete find_program call..." -ForegroundColor Yellow
    $content = $content -replace '(?s)(find_program\([^)]*ENV PATH)\s*\n(?!\))', '$1)`n'
    $found = $true
}

# Fix any execute_process calls missing closing parenthesis
if ($content -match 'execute_process\s*\(\s*COMMAND[^)]*$') {
    Write-Host "Fixing incomplete execute_process call..." -ForegroundColor Yellow
    # This is more complex, so we'll handle it in the NuGet section replacement
}

if ($found) {
    Set-Content $flutterTtsPath $content -NoNewline
    Write-Host "Fixed NuGet section!" -ForegroundColor Green
} else {
    Write-Host "Warning: Could not find NuGet section to replace. File may have different structure." -ForegroundColor Yellow
    Write-Host "The file may already be fixed or have a different format." -ForegroundColor Yellow
}

# Fix incomplete set() function for bundled_libraries (common error at line 95)
Write-Host "Checking for incomplete set() function..." -ForegroundColor Cyan
$needsReload = $false

# Check for missing closing parenthesis
if ($content -match '(?s)set\(flutter_tts_bundled_libraries\s+""\s+PARENT_SCOPE\s+################ NuGet import begin') {
    Write-Host "Fixing incomplete set() function for bundled_libraries..." -ForegroundColor Yellow
    # Fix: Add closing parenthesis and proper newline
    $content = $content -replace '(?s)(set\(flutter_tts_bundled_libraries\s+""\s+PARENT_SCOPE)\s+(################ NuGet import begin)', "`$1)`r`n`r`n`$2"
    Set-Content $flutterTtsPath $content -NoNewline
    Write-Host "Fixed incomplete set() function!" -ForegroundColor Green
    $needsReload = $true
} 
# Check for literal \n character (should be actual newline)
elseif ($content.Contains('PARENT_SCOPE)`n################')) {
    Write-Host "Fixing literal newline character in set() function..." -ForegroundColor Yellow
    $content = $content.Replace('PARENT_SCOPE)`n################', "PARENT_SCOPE)`r`n`r`n################")
    [System.IO.File]::WriteAllText($flutterTtsPath, $content)
    Write-Host "Fixed literal newline character!" -ForegroundColor Green
    $needsReload = $true
}
# Check for missing newline after closing parenthesis
elseif ($content -match 'PARENT_SCOPE\)\s+################ NuGet import begin') {
    Write-Host "Fixing newline formatting after set() function..." -ForegroundColor Yellow
    $content = $content -replace '(PARENT_SCOPE\))\s+(################ NuGet import begin)', "`$1`r`n`r`n`$2"
    Set-Content $flutterTtsPath $content -NoNewline
    Write-Host "Fixed newline formatting!" -ForegroundColor Green
    $needsReload = $true
}

# Reload content if we made changes
if ($needsReload) {
    $content = Get-Content $flutterTtsPath -Raw
}

# Fix Windows Runtime library linkage
Write-Host "Checking Windows Runtime library linkage..." -ForegroundColor Cyan

if ($content -notmatch "windowsapp\.lib") {
    # Add windowsapp.lib after flutter_wrapper_plugin
    if ($content -match "(target_link_libraries\(\$\{PLUGIN_NAME\} PRIVATE flutter flutter_wrapper_plugin\))") {
        $replacement = '$1' + "`n`n# Link Windows Runtime library for WinRT support`ntarget_link_libraries(`${PLUGIN_NAME} PRIVATE windowsapp.lib)"
        $content = $content -replace "(target_link_libraries\(\$\{PLUGIN_NAME\} PRIVATE flutter flutter_wrapper_plugin\))", $replacement
        Set-Content $flutterTtsPath $content -NoNewline
        Write-Host "Added windowsapp.lib linkage!" -ForegroundColor Green
    } else {
        Write-Host "Warning: Could not find target_link_libraries section to add windowsapp.lib" -ForegroundColor Yellow
    }
} else {
    Write-Host "Windows Runtime library already linked!" -ForegroundColor Green
}

# Final syntax check
$finalOpenParens = ([regex]::Matches($content, '\(')).Count
$finalCloseParens = ([regex]::Matches($content, '\)')).Count
if ($finalOpenParens -eq $finalCloseParens) {
    Write-Host "Syntax check passed: All parentheses balanced!" -ForegroundColor Green
} else {
    Write-Host "Warning: Syntax check failed. Open: $finalOpenParens, Close: $finalCloseParens" -ForegroundColor Yellow
    Write-Host "The file may still have issues. Please review manually." -ForegroundColor Yellow
}

Write-Host "`nflutter_tts CMakeLists.txt fixed successfully!" -ForegroundColor Green
Write-Host "You can now try building again: flutter run -d windows" -ForegroundColor Cyan

