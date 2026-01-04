# Download Python Embeddable Package
param(
    [string]$PythonVersion = "3.13.1",
    [string]$Architecture = "amd64",  # amd64 or win32
    [string]$TargetDir = "..\runtime"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  Python Embeddable Package Downloader" -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Python Version: $PythonVersion"
Write-Host "Architecture:   $Architecture"
Write-Host ""

# Construct download URL
$PythonVersionShort = $PythonVersion -replace '\.', ''
$DownloadUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-$Architecture.zip"
$ZipFile = "python-embed.zip"

Write-Host "[1/5] Downloading Python embeddable package..." -ForegroundColor Yellow
Write-Host "      URL: $DownloadUrl" -ForegroundColor Gray

try {
    # Download with progress
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipFile -UseBasicParsing
    Write-Host "      Done." -ForegroundColor Green
} catch {
    Write-Host "      ERROR: Download failed!" -ForegroundColor Red
    Write-Host "      $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Check if target directory exists
Write-Host "[2/5] Preparing target directory..." -ForegroundColor Yellow
$FullTargetPath = Join-Path $PSScriptRoot $TargetDir
if (Test-Path $FullTargetPath) {
    Write-Host "      Removing old runtime..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $FullTargetPath
}
New-Item -ItemType Directory -Path $FullTargetPath -Force | Out-Null
Write-Host "      Done." -ForegroundColor Green
Write-Host ""

# Extract
Write-Host "[3/5] Extracting Python embeddable package..." -ForegroundColor Yellow
try {
    Expand-Archive -Path $ZipFile -DestinationPath $FullTargetPath -Force
    Write-Host "      Done." -ForegroundColor Green
} catch {
    Write-Host "      ERROR: Extraction failed!" -ForegroundColor Red
    Write-Host "      $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Configure Python path
Write-Host "[4/5] Configuring Python path..." -ForegroundColor Yellow
$PthFile = Get-ChildItem -Path $FullTargetPath -Filter "python*._pth" | Select-Object -First 1

if ($PthFile) {
    $PthContent = @"
python$($PythonVersionShort.Substring(0,3)).zip
.
..
..\site-packages
.\Lib

import site
"@
    $PthContent | Out-File -Encoding ASCII -FilePath $PthFile.FullName
    Write-Host "      Configured: $($PthFile.Name)" -ForegroundColor Gray
    Write-Host "      Done." -ForegroundColor Green
} else {
    Write-Host "      WARNING: ._pth file not found!" -ForegroundColor Yellow
}
Write-Host ""

# Create Lib/tkinter directory if needed
Write-Host "[5/5] Creating required directories..." -ForegroundColor Yellow
$LibDir = Join-Path $FullTargetPath "Lib"
if (-not (Test-Path $LibDir)) {
    New-Item -ItemType Directory -Path $LibDir -Force | Out-Null
}
Write-Host "      Done." -ForegroundColor Green
Write-Host ""

# Clean up
Remove-Item -Force $ZipFile

# Summary
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "  Runtime downloaded and configured successfully!" -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Location: $FullTargetPath"
Write-Host "Python:   $PythonVersion ($Architecture)"
Write-Host ""

# Test Python
Write-Host "Testing Python executable..." -ForegroundColor Yellow
$PythonExe = Join-Path $FullTargetPath "python.exe"
if (Test-Path $PythonExe) {
    & $PythonExe --version
    Write-Host ""
    Write-Host "Python runtime is ready to use!" -ForegroundColor Green
} else {
    Write-Host "ERROR: python.exe not found!" -ForegroundColor Red
}

Write-Host ""