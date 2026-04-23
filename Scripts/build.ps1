# ABC Project Unified Build Script

$MQL5_COMPILER = "D:\Program Files\XM Global MT5\MetaEditor64.exe"
$LOG_DIR = "..\_log"
$XTS_PATH = "..\XTS"
$XTE_PATH = "..\XTE"

if (-not (Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Path $LOG_DIR }

Write-Host "--- Building XTS (C#) ---" -ForegroundColor Cyan
cd $XTS_PATH
dotnet build /flp:logfile="$LOG_DIR\build_xts.log";verbosity=minimal

Write-Host "`n--- Building XTE (MQL5) ---" -ForegroundColor Cyan
cd $XTE_PATH
# Experts 내의 모든 mq5 파일 컴파일 시도
Get-ChildItem -Path "Experts" -Filter "*.mq5" | ForEach-Object {
    $file = $_.FullName
    Write-Host "Compiling $($_.Name)..."
    Start-Process -FilePath $MQL5_COMPILER -ArgumentList "/compile:`"$file`"", "/log:`"$LOG_DIR\build_xte.log`"" -Wait
}

Write-Host "`nBuild Process Completed. Check $LOG_DIR for details." -ForegroundColor Green
