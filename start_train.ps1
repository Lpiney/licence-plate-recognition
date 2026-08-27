<#
.SYNOPSIS
    One-click training launcher: cleans residual python processes, checks GPU,
    then starts license plate detection training in the lpr conda env.
.DESCRIPTION
    Fixes repeated memory/VRAM overflow on Windows:
      1. Kills all residual python processes left by failed/interrupted runs
      2. Shows GPU memory usage before training
      3. Starts train.py via conda run (no manual env activation needed)

    All paths are derived automatically (no hardcoded user paths), so this
    script works on any machine without modification.
.USAGE
    powershell -ExecutionPolicy Bypass -File <项目根目录>\start_train.ps1
.NOTES
    Keep the console window open while training runs.
    Press Ctrl+C to interrupt (residuals will be auto-cleaned next run).
#>

$ErrorActionPreference = "Continue"

# Auto-detect project dir from this script's location (no hardcoded path)
$ProjectDir = $PSScriptRoot

# Locate conda in the current user's home (no hardcoded username)
$CondaBat = Join-Path $env:USERPROFILE "miniconda3\Library\bin\conda.BAT"
if (-not (Test-Path $CondaBat)) {
    # fallback: try conda on PATH
    $CondaBat = "conda.BAT"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  License Plate Training Launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Project: $ProjectDir" -ForegroundColor DarkGray
Write-Host "  Conda:   $CondaBat" -ForegroundColor DarkGray

# ---- Step 1: clean residual python processes ----
Write-Host ""
Write-Host "[1/3] Cleaning residual python processes..." -ForegroundColor Yellow
$procs = Get-Process python* -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "  Found $($procs.Count) residual process(es), killing..." -ForegroundColor Yellow
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
} else {
    Write-Host "  Clean, no residual processes" -ForegroundColor Green
}

# ---- Step 2: check GPU memory ----
Write-Host ""
Write-Host "[2/3] Checking GPU memory usage..." -ForegroundColor Yellow
$gpu = nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>$null
Write-Host "  Current GPU memory used: $gpu (should be < 2GB before training)" -ForegroundColor Yellow

# ---- Step 3: start training ----
Write-Host ""
Write-Host "[3/3] Starting training (lpr env)..." -ForegroundColor Green
Write-Host "  Script: $ProjectDir\train.py"
Write-Host "  Press Ctrl+C to interrupt training" -ForegroundColor DarkGray
Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Cyan
& $CondaBat run --no-capture-output -n lpr python "$ProjectDir\train.py"

# ---- Done ----
Write-Host ""
Write-Host "Training finished (exit code: $LASTEXITCODE)" -ForegroundColor Cyan
Write-Host "Result: $ProjectDir\runs\plate\weights\best.pt" -ForegroundColor Green
