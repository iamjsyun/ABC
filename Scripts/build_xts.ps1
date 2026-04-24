# Build script for XTS (C#)

# Define paths relative to the script's location (Scripts/)
$LOG_DIR = "..\_log" # Logs directory is one level up from Scripts
$XTS_PROJECT_PATH = "..\XTS" # Path to the XTS project directory

# Ensure log directory exists
if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
}

Write-Host "--- Building XTS (C#) ---" -ForegroundColor Cyan

# Check if the XTS project directory exists
if (-not (Test-Path $XTS_PROJECT_PATH)) {
    Write-Error "XTS project path not found at '$XTS_PROJECT_PATH'. Please check the path."
    exit 1
}

# Construct the full path for the log file
$logFilePath = Join-Path $PSScriptRoot $LOG_DIR "build_xts.log"

# Use dotnet build with logging.
# Push-Location changes the current directory for the command.
Push-Location $XTS_PROJECT_PATH
dotnet build /flp:logfile="$logFilePath";verbosity=minimal
Pop-Location

Write-Host "XTS Build Process Completed. Check '$LOG_DIR' for details." -ForegroundColor Green
