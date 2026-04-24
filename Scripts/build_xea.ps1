# Build script for XEA (MQL5)

$MQL5_COMPILER = "D:\Program Files\XM Global MT5\MetaEditor64.exe"
$LOG_DIR_RELATIVE = "..\_log" # Relative path from script directory
$XEA_MAIN_FILE_RELATIVE = "..\XEA\Experts\XEA.mq5" # Relative path from script directory

# Ensure log directory exists
$logDirFullPath = Join-Path $PSScriptRoot $LOG_DIR_RELATIVE
if (-not (Test-Path $logDirFullPath)) {
    New-Item -ItemType Directory -Path $logDirFullPath -Force | Out-Null
}

Write-Host "--- Building XEA (MQL5) ---" -ForegroundColor Cyan

# Construct the full path for the XEA main file
$xeaMainFileFullPath = Join-Path $PSScriptRoot $XEA_MAIN_FILE_RELATIVE

# Check if the main MQL5 file exists
if (-not (Test-Path $xeaMainFileFullPath)) {
    Write-Error "XEA main file not found at '$xeaMainFileFullPath'. Please check the path."
    exit 1
}

# Construct the full path for the log file
$logFilePath = Join-Path $logDirFullPath "build_xea.log"

Write-Host "Compiling $($xeaMainFileFullPath)..."
# Use Start-Process with full path for the MQL5 compiler and the file.
Start-Process -FilePath $MQL5_COMPILER -ArgumentList "/compile:`"$xeaMainFileFullPath`"", "/log:`"$logFilePath`"" -Wait -NoNewWindow

Write-Host "XEA Build Process Completed. Check '$logDirFullPath' for details." -ForegroundColor Green
