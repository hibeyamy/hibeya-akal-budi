param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$phase = Join-Path $root "phase007h-format-agnostic-assets.ps1"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007h-repair-v2-$runId.log"

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

function Log([string]$Message) {
  Write-Host $Message
  Add-Content -Path $log -Value $Message -Encoding UTF8
}

trap {
  WriteText $log @"
PHASE 007H REPAIR V2 FAILED

TIME:
$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")

MESSAGE:
$($_.Exception.Message)

ERROR:
$($_ | Out-String)

POSITION:
$($_.InvocationInfo.PositionMessage)

STACK:
$($_.ScriptStackTrace)
"@

  Write-Host ""
  Write-Host "PHASE 007H REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007H REPAIR V2" -ForegroundColor Cyan
Write-Host "Fix Node ESM temp-script extension" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $phase)) {
  throw "Phase 007H installer not found: $phase"
}

$backup = Join-Path $backups "$runId-phase007h-format-agnostic-assets.ps1"
Copy-Item $phase $backup -Force
Log "Backup: $backup"

$source = Get-Content $phase -Raw

$old = 'hibeya-phase007h-schema.cjs'
$new = 'hibeya-phase007h-schema.mjs'

if ($source.Contains($old)) {
  $source = $source.Replace($old,$new)
  WriteText $phase $source
  Log "PASS: schema helper changed from .cjs to .mjs"
}
elseif ($source.Contains($new)) {
  Log "PASS: schema helper already uses .mjs"
}
else {
  throw "Could not locate Phase 007H schema helper filename."
}

if ($source -notmatch 'import fs from "node:fs";') {
  throw "Expected ESM import syntax not found in Phase 007H schema helper."
}

Log "PASS: ESM helper syntax verified"

Log ""
Log "==> Re-running Phase 007H"

$args = @(
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  $phase
)

if ($Commit) {
  $args += "-Commit"
}

& powershell.exe @args

if ($LASTEXITCODE -ne 0) {
  throw "Phase 007H still failed with exit code $LASTEXITCODE."
}

Log ""
Log "PHASE 007H REPAIR V2: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007H REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No manual file edit was required." -ForegroundColor Cyan
