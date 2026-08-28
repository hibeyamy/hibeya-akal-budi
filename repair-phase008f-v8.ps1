param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$target = Join-Path $root "repair-phase008f-v7.ps1"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008f-repair-v8-$runId.log"

function WriteText([string]$Path,[string]$Content) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    [IO.File]::WriteAllText(
        $Path,
        $Content.TrimEnd() + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

trap {
    Add-Content `
        $log `
        "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
        -Encoding UTF8

    Write-Host ""
    Write-Host "PHASE 008F REPAIR V8: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008F REPAIR V8" -ForegroundColor Cyan
Write-Host "Fix reserved PowerShell Error variable collision" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $target)) {
    throw "Missing V7 repair script: $target"
}

Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "CLR:        $($PSVersionTable.CLRVersion)"

$backup = Join-Path $backups "$runId-repair-phase008f-v7.ps1"
Copy-Item $target $backup -Force
Write-Host "Backup: $backup" -ForegroundColor Cyan

$source = Get-Content $target -Raw
$normalised = $source.Replace("`r`n","`n")

$old = @'
if ($errors.Count -gt 0) {
    foreach ($error in $errors) {
        Add-Content $log $error.Message -Encoding UTF8
    }

    throw "Patched V6 failed PowerShell parser validation."
}
'@

$new = @'
if ($errors.Count -gt 0) {
    foreach ($parseError in $errors) {
        Add-Content $log $parseError.Message -Encoding UTF8
    }

    throw "Patched V6 failed PowerShell parser validation."
}
'@

if (-not $normalised.Contains($old)) {
    throw "Expected reserved-variable parser loop was not found in V7. Refusing blind patch."
}

$patched = $normalised.Replace($old,$new)

WriteText $target $patched
Write-Host "PASS: reserved variable collision repaired" -ForegroundColor Green

# Validate the patched V7 parser without using the reserved $Error automatic variable.
$tokens = $null
$parseErrors = $null

[void][System.Management.Automation.Language.Parser]::ParseFile(
    $target,
    [ref]$tokens,
    [ref]$parseErrors
)

if ($parseErrors.Count -gt 0) {
    foreach ($parseIssue in $parseErrors) {
        Add-Content $log $parseIssue.Message -Encoding UTF8
        Write-Host "Parser error: $($parseIssue.Message)" -ForegroundColor Red
    }

    throw "Patched V7 still contains PowerShell parser errors."
}

Write-Host "PASS: V7 parser validation" -ForegroundColor Green

Write-Host ""
Write-Host "==> Re-running repaired Phase 008F V7" -ForegroundColor Cyan

$args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $target
)

if ($Commit) {
    $args += "-Commit"
}

& powershell.exe @args

$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    throw "Repaired Phase 008F V7 still failed with exit code $exitCode. Review tools\dev\logs\phase008f-repair-v7-*.log"
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008F REPAIR V8: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
