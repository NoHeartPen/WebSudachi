
# WebSudachi Package Creator
param(
    [string]$Version = "1.0.0",
    [string]$PythonVersion = "3.13.1",
    [string]$Architecture = "amd64",
    [switch]$SkipRuntimeDownload,
    [switch]$SkipDependencies
)

$ErrorActionPreference = "Stop"

# Get paths
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildDir = $PSScriptRoot

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  WebSudachi Package Creator v$Version" -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

Set-Location $ProjectRoot

# ============================================================================
# Pre-build checks and setup
# ============================================================================

# Check/Download runtime
Write-Host "[Pre-check 1/2] Checking Python runtime..." -ForegroundColor Magenta
if (-not (Test-Path "runtime\python.exe")) {
    if ($SkipRuntimeDownload) {
        Write-Host "      ERROR: Runtime not found and skip download is enabled!" -ForegroundColor Red
        exit 1
    }

    Write-Host "      Runtime not found. Downloading..." -ForegroundColor Yellow
    Write-Host ""

    $downloadScript = Join-Path $BuildDir "download_runtime.ps1"
    if (Test-Path $downloadScript) {
        & $downloadScript -PythonVersion $PythonVersion -Architecture $Architecture
        Write-Host ""
    } else {
        Write-Host "      ERROR: download_runtime.ps1 not found!" -ForegroundColor Red
        exit 1
    }
} else {
    $versionOutput = & runtime\python.exe --version 2>&1
    Write-Host "      Found: $versionOutput" -ForegroundColor Green
}
Write-Host ""

# Check/Install dependencies
Write-Host "[Pre-check 2/2] Checking dependencies..." -ForegroundColor Magenta
$sitePackagesExists = Test-Path "site-packages"
$dependenciesComplete = $false

if ($sitePackagesExists) {
    # Check if critical packages exist
    $hasFastapi = Test-Path "site-packages\fastapi"
    $hasUvicorn = Test-Path "site-packages\uvicorn"
    $hasSudachipy = Test-Path "site-packages\sudachipy"

    if ($hasFastapi -and $hasUvicorn -and $hasSudachipy) {
        Write-Host "      Dependencies found." -ForegroundColor Green
        $dependenciesComplete = $true
    } else {
        Write-Host "      Incomplete dependencies detected." -ForegroundColor Yellow
        $sitePackagesExists = $false
    }
}

if (-not $dependenciesComplete -and -not $SkipDependencies) {
    Write-Host "      Installing dependencies..." -ForegroundColor Yellow
    Write-Host ""

    # Check if pip is available
    Write-Host "      Checking pip..." -ForegroundColor Gray
    $pipInstalled = $false

    try {
        $null = & runtime\python.exe -m pip --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $pipInstalled = $true
            Write-Host "      pip is available." -ForegroundColor Green
        }
    } catch {
        # pip not found, will install
    }

    if (-not $pipInstalled) {
        Write-Host "      pip not found. Installing..." -ForegroundColor Yellow

        # Download get-pip.py
        if (-not (Test-Path "get-pip.py")) {
            Write-Host "      Downloading get-pip.py..." -ForegroundColor Gray
            try {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile "get-pip.py" -UseBasicParsing
            } catch {
                Write-Host "      ERROR: Failed to download get-pip.py" -ForegroundColor Red
                Write-Host "      $_" -ForegroundColor Red
                exit 1
            }
        }

        # Install pip
        Write-Host "      Installing pip..." -ForegroundColor Gray
        $pipInstallOutput = & runtime\python.exe get-pip.py --no-warn-script-location 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "      ERROR: pip installation failed!" -ForegroundColor Red
            Write-Host "      $pipInstallOutput" -ForegroundColor Red
            exit 1
        }

        Write-Host "      pip installed successfully." -ForegroundColor Green
    }

    # Install dependencies
    Write-Host "      Installing packages from requirements.txt..." -ForegroundColor Gray
    Write-Host ""

    if (-not (Test-Path "site-packages")) {
        New-Item -ItemType Directory -Path "site-packages" | Out-Null
    }

    $installOutput = & runtime\python.exe -m pip install -r requirements.txt `
        --target site-packages `
        --no-cache-dir `
        --no-warn-script-location 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "      ERROR: Dependencies installation failed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Error output:" -ForegroundColor Yellow
        Write-Host $installOutput
        Write-Host ""
        Write-Host "You can try:" -ForegroundColor Yellow
        Write-Host "  1. Run: build\setup_dependencies.bat" -ForegroundColor Gray
        Write-Host "  2. Check network connection" -ForegroundColor Gray
        Write-Host "  3. Use mirror: pip install ... -i https://pypi.tuna.tsinghua.edu.cn/simple" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }

    Write-Host ""
    Write-Host "      Dependencies installed successfully." -ForegroundColor Green
} elseif ($SkipDependencies) {
    Write-Host "      Skipped (as requested)." -ForegroundColor Gray
}
Write-Host ""

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  Starting package build..." -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Build package
# ============================================================================

$PKG = "WebSudachi-Package"
$APP = "$PKG\WebSudachi"
$ZIPNAME = "WebSudachi-v$Version.zip"

# Step 1: Clean
Write-Host "[1/7] Cleaning old files..." -ForegroundColor Yellow
if (Test-Path $PKG) {
    Remove-Item -Recurse -Force $PKG
}
if (Test-Path $ZIPNAME) {
    Remove-Item -Force $ZIPNAME
}
New-Item -ItemType Directory -Path $APP -Force | Out-Null
Write-Host "      Done." -ForegroundColor Green
Write-Host ""

# Step 2: Copy runtime
Write-Host "[2/7] Copying runtime..." -ForegroundColor Yellow
Copy-Item -Recurse -Force "runtime" "$APP\runtime"

# Show runtime info
$pythonExe = "$APP\runtime\python.exe"
if (Test-Path $pythonExe) {
    $versionOutput = & $pythonExe --version 2>&1
    Write-Host "      Python: $versionOutput" -ForegroundColor Gray
}

Write-Host "      Done." -ForegroundColor Green
Write-Host ""

# Step 3: Copy application files
Write-Host "[3/7] Copying application files..." -ForegroundColor Yellow
$folders = @("site-packages", "static", "templates")
$copiedCount = 0

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Copy-Item -Recurse -Force $folder "$APP\$folder"
        $copiedCount++
    } else {
        Write-Host "      WARNING: $folder not found!" -ForegroundColor Yellow
    }
}

$files = @("app.py", "WebSudachi.exe", "WebSudachi.int", "LICENSE", "requirements.txt")
foreach ($file in $files) {
    if (Test-Path $file) {
        Copy-Item -Force $file "$APP\"
    } else {
        Write-Host "      WARNING: $file not found!" -ForegroundColor Yellow
    }
}

# Create .env for packaged version (full features enabled)
$envContent = @"
# WebSudachi Packaged Version Configuration
# Full features are enabled for self-deployed packages
IS_DEMO_DEPLOY=false
"@
$envContent | Out-File -Encoding UTF8 "$APP\.env"
Write-Host "      Created .env (IS_DEMO_DEPLOY=false)" -ForegroundColor Gray

Write-Host "      Copied $copiedCount folders + files" -ForegroundColor Gray
Write-Host "      Done." -ForegroundColor Green
Write-Host ""

# Step 4: Copy build utilities
Write-Host "[4/7] Copying build utilities..." -ForegroundColor Yellow
if (Test-Path "$BuildDir\setup_dependencies.bat") {
    Copy-Item -Force "$BuildDir\setup_dependencies.bat" "$APP\"
}
Write-Host "      Done." -ForegroundColor Green
Write-Host ""

# Step 5: Create launcher
Write-Host "[5/7] Creating launcher..." -ForegroundColor Yellow
$launcherTemplate = "$BuildDir\Start.bat.template"
if (Test-Path $launcherTemplate) {
    Copy-Item -Force $launcherTemplate "$PKG\Start.bat"
} else {
    $launcher = @'
@echo off
chcp 65001 >nul 2>&1
title WebSudachi
cd /d "%~dp0"
if not exist "WebSudachi\runtime\python.exe" (
    echo ERROR: WebSudachi directory not found!
    pause
    exit /b 1
)
cd WebSudachi
runtime\python.exe WebSudachi.int
if errorlevel 1 pause
'@
    $launcher | Out-File -Encoding ASCII "$PKG\Start.bat"
}
Write-Host "      Done." -ForegroundColor Green
Write-Host ""

# Step 6: Create README
Write-Host "[6/7] Creating README..." -ForegroundColor Yellow
$readmeTemplate = "$BuildDir\README.txt.template"
if (Test-Path $readmeTemplate) {
    $readmeContent = Get-Content $readmeTemplate -Raw
    $readmeContent = $readmeContent -replace '{{VERSION}}', $Version
    $readmeContent = $readmeContent -replace '{{DATE}}', (Get-Date -Format "yyyy-MM-dd")
    $readmeContent | Out-File -Encoding UTF8 "$PKG\README.txt"
} else {
    $readme = @"
================================================================================
  WebSudachi v$Version
================================================================================
Quick Start: Double-click Start.bat
================================================================================
"@
    $readme | Out-File -Encoding UTF8 "$PKG\README.txt"
}
Write-Host "      Done." -ForegroundColor Green
Write-Host ""

# Step 7: Create ZIP
Write-Host "[7/7] Creating ZIP archive..." -ForegroundColor Yellow
try {
    Compress-Archive -Path $PKG -DestinationPath $ZIPNAME -CompressionLevel Optimal -Force
    Write-Host "      Done." -ForegroundColor Green
    Write-Host ""

    # Summary
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "  Package created successfully!" -ForegroundColor White
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host ""

    $zipInfo = Get-Item $ZIPNAME
    $folderSize = (Get-ChildItem -Path $PKG -Recurse | Measure-Object -Property Length -Sum).Sum

    Write-Host "ZIP File:" -ForegroundColor Cyan
    Write-Host "  Name:     $($zipInfo.Name)"
    Write-Host "  Location: $($zipInfo.Directory.FullName)"
    Write-Host "  Size:     $([math]::Round($zipInfo.Length / 1MB, 2)) MB"
    Write-Host ""
    Write-Host "Package Folder:" -ForegroundColor Cyan
    Write-Host "  Size:     $([math]::Round($folderSize / 1MB, 2)) MB"
    Write-Host "  Files:    $((Get-ChildItem -Path $PKG -Recurse -File).Count)"
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Test:  $PKG\Start.bat"
    Write-Host "  2. Share: $ZIPNAME"
    Write-Host ""

} catch {
    Write-Host "      ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")