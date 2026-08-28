param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$phasePath = Join-Path $root "phase007d-first-original-asset-batch.ps1"
$playerPath = Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007d-repair-v4-$runId.log"

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
PHASE 007D REPAIR V4 FAILED

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
  Write-Host "PHASE 007D REPAIR V4: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007D REPAIR V4" -ForegroundColor Cyan
Write-Host "Recognise existing multiline image support" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $phasePath)) {
  throw "Phase 007D installer not found: $phasePath"
}

if (-not (Test-Path $playerPath)) {
  throw "ActivityPlayer not found: $playerPath"
}

# ------------------------------------------------------------
# 1. Verify that ActivityPlayer ALREADY supports image assets.
#    The user's current JSX has:
#
#      asset.type ===
#      "image"
#
#    so the old exact-string guard did not recognise it.
# ------------------------------------------------------------

$playerSource = Get-Content $playerPath -Raw

if (
  $playerSource -notmatch
  'asset\.type\s*===\s*["'']image["'']'
) {
  throw "ActivityPlayer does not contain recognised image rendering support."
}

if (
  $playerSource -notmatch
  '<img[\s\S]*?src\s*=\s*\{\s*asset\.value\s*\}'
) {
  throw "ActivityPlayer image branch exists but src={asset.value} could not be verified."
}

Log "PASS: existing ActivityPlayer image rendering verified"
Log "No manual ActivityPlayer edit is required."

# ------------------------------------------------------------
# 2. Patch ONLY the installer guard so reruns are idempotent.
# ------------------------------------------------------------

$backup = Join-Path $backups "$runId-phase007d-first-original-asset-batch.ps1"
Copy-Item $phasePath $backup -Force
Log "Backup: $backup"

$phaseSource = Get-Content $phasePath -Raw

$oldGuard = "if (s.includes('asset.type === `"image`"')) {"
$newGuard = "if (/asset\.type\s*===\s*['`"]image['`"]/.test(s)) {"

if ($phaseSource.Contains($oldGuard)) {
  $phaseSource = $phaseSource.Replace($oldGuard, $newGuard)

  WriteText $phasePath $phaseSource
  Log "PASS: Phase 007D image-support guard upgraded"
}
elseif (
  $phaseSource -match
  '/asset\\\.type\\s\*===\\s\*\['
) {
  Log "PASS: Phase 007D guard already upgraded"
}
else {
  throw "Could not locate the legacy ActivityPlayer image-support guard in Phase 007D installer."
}

# ------------------------------------------------------------
# 3. Immediate checks before full rerun.
# ------------------------------------------------------------

Log ""
Log "==> Learner web typecheck"

& pnpm --filter learner-web typecheck

if ($LASTEXITCODE -ne 0) {
  throw "learner-web typecheck failed before Phase 007D rerun."
}

Log "PASS: learner-web typecheck"

Log ""
Log "==> Asset package typecheck"

& pnpm --filter @akal-budi/assets typecheck

if ($LASTEXITCODE -ne 0) {
  throw "@akal-budi/assets typecheck failed before Phase 007D rerun."
}

Log "PASS: @akal-budi/assets typecheck"

# ------------------------------------------------------------
# 4. Rerun the full Phase 007D pipeline.
# ------------------------------------------------------------

Log ""
Log "==> Re-running Phase 007D"

$args = @(
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  $phasePath
)

if ($Commit) {
  $args += "-Commit"
}

& powershell.exe @args

if ($LASTEXITCODE -ne 0) {
  throw "Phase 007D still failed with exit code $LASTEXITCODE."
}

Log ""
Log "PHASE 007D REPAIR V4: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007D REPAIR V4: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No manual code edit was required." -ForegroundColor Cyan
Write-Host "Next manual step, only after Phase 007D passes:" -ForegroundColor Cyan
Write-Host "  pnpm storybook" -ForegroundColor White
Write-Host "Then review Assets -> First Original Batch -> Review Gallery" -ForegroundColor White
Write-Host "Log: $log" -ForegroundColor DarkGray
