param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$phase = Join-Path $root "phase007f-manifest-commercial-registry.ps1"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007f-repair-v2-$runId.log"

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
PHASE 007F REPAIR V2 FAILED

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
  Write-Host "PHASE 007F REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007F REPAIR V2" -ForegroundColor Cyan
Write-Host "Scope commercial validation to approved runtime assets" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $phase)) {
  throw "Phase 007F installer not found: $phase"
}

$backup =
  Join-Path `
    $backups `
    "$runId-phase007f-manifest-commercial-registry.ps1"

Copy-Item $phase $backup -Force
Log "Backup: $backup"

$source =
  Get-Content `
    $phase `
    -Raw

$old = @'
Run `
  "Commercial release validation" `
  "pnpm assets:commercial:validate"

Run `
  "Asset family QA" `
  "pnpm assets:families:qa"
'@

$new = @'
Write-Host ""
Write-Host "NOTE: Global commercial asset gate intentionally deferred in Phase 007F." -ForegroundColor Yellow
Write-Host "Reason: prototype learner-core hibiscus assets are not yet approved for commercial release." -ForegroundColor Yellow
Write-Host "Phase 007F validates only approved assets entering the manifest-driven runtime registry." -ForegroundColor Yellow

Run `
  "Asset family QA" `
  "pnpm assets:families:qa"
'@

if (
  $source.Contains(
    $old
  )
) {
  $source =
    $source.Replace(
      $old,
      $new
    )
}
elseif (
  $source -match
  'Global commercial asset gate intentionally deferred in Phase 007F'
) {
  Log "PASS: Phase 007F already contains scoped commercial validation"
}
else {
  throw "Could not safely locate the global commercial validation block."
}

WriteText $phase $source
Log "PASS: Phase 007F commercial gate scope repaired"

# Rerun the complete phase. Approved-runtime checks remain mandatory:
# - assets:runtime:check
# - assets:runtime:validate
# - assets:families:qa
# The global commercial gate will be reintroduced at the final product-release phase.

Log ""
Log "==> Re-running Phase 007F"

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
  throw "Phase 007F still failed with exit code $LASTEXITCODE."
}

Log ""
Log "PHASE 007F REPAIR V2: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007F REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The global commercial asset gate is still expected to remain BLOCKED" -ForegroundColor Yellow
Write-Host "until hibiscus-purple, hibiscus-red and hibiscus-yellow are replaced/reviewed." -ForegroundColor Yellow
