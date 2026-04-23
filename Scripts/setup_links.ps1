# Setup Directory Junctions for MQL5 <-> Project Integration

$COMMON_PATH = "$env:AppData\MetaQuotes\Terminal\Common\MQL5\Files\ABC"
$PROJECT_ROOT = Get-Location
$LOG_PATH = Join-Path $PROJECT_ROOT "_log"
$DATA_PATH = Join-Path $PROJECT_ROOT "Shared\Data"

# 1. MQL5 Common 폴더 생성
if (-not (Test-Path $COMMON_PATH)) { 
    New-Item -ItemType Directory -Path $COMMON_PATH -Force 
}

# 2. _log 연결
if (Test-Path $LOG_PATH) { 
    Write-Host "Cleaning up existing _log folder..."
    Remove-Item -Path $LOG_PATH -Recurse -Force 
}
cmd /c mklink /J "$LOG_PATH" "$COMMON_PATH"

# 3. Shared/Data 연결
if (-not (Test-Path "$PROJECT_ROOT\Shared")) { New-Item -ItemType Directory -Path "$PROJECT_ROOT\Shared" }
if (Test-Path $DATA_PATH) { 
    Remove-Item -Path $DATA_PATH -Recurse -Force 
}
# Data 폴더는 별도로 분리하여 연결 (DB 파일 등 저장용)
$MQL5_DATA_PATH = New-Item -ItemType Directory -Path (Join-Path $COMMON_PATH "Data") -Force
cmd /c mklink /J "$DATA_PATH" "$MQL5_DATA_PATH"

Write-Host "`nIntegration Setup Complete!" -ForegroundColor Green
Write-Host "MQL5 Common Path: $COMMON_PATH"
Write-Host "Project Log Path: $LOG_PATH (Linked)"
Write-Host "Project Data Path: $DATA_PATH (Linked)"
