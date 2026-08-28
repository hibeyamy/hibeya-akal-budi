param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$phasePath = Join-Path $repoRoot "phase006b-v7.ps1"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006b-v10-repair-$runId.log"

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $dir = Split-Path -Parent $Path

  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  [System.IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Log {
  param([string]$Message)

  Write-Host $Message
  Add-Content -Path $sessionLog -Value $Message -Encoding UTF8
}

trap {
  $details = @"
PHASE 006B V10 REPAIR FAILED

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

  Write-Utf8NoBom -Path $sessionLog -Content $details

  Write-Host ""
  Write-Host "Phase 006B V10 repair failed." -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006B REPAIR V10" -ForegroundColor Cyan
Write-Host "Fix TypeScript CSS side-effect module typing" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $phasePath)) {
  throw "phase006b-v7.ps1 not found in repository root."
}

# ------------------------------------------------------------
# TypeScript 6 validates side-effect imports more strictly.
# The UI package imports ./styles.css from index.ts, so provide
# an explicit CSS module declaration. Storybook also imports CSS.
# ------------------------------------------------------------

Log ""
Log "==> Adding CSS module declarations"

$uiDeclaration = @'
declare module "*.css";
'@

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot "packages\ui\src\styles.d.ts") `
  -Content $uiDeclaration

Write-Utf8NoBom `
  -Path (Join-Path $repoRoot "apps\ui-storybook\.storybook\styles.d.ts") `
  -Content $uiDeclaration

Log "PASS: CSS module declarations created"

# ------------------------------------------------------------
# Verify the immediate failing gate before rerunning everything.
# ------------------------------------------------------------

Log ""
Log "==> Verifying @akal-budi/ui typecheck"

& pnpm --filter @akal-budi/ui typecheck

if ($LASTEXITCODE -ne 0) {
  throw "@akal-budi/ui typecheck still fails after CSS declaration fix."
}

Log "PASS: @akal-budi/ui typecheck"

# ------------------------------------------------------------
# Rerun full Phase 006B V7. Existing build approval remains in
# pnpm-workspace.yaml from V9.
# ------------------------------------------------------------

Log ""
Log "==> Re-running complete Phase 006B V7 pipeline"

$arguments = @(
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  $phasePath
)

if ($Commit) {
  $arguments += "-Commit"
}

& powershell.exe @arguments

$phaseExitCode = $LASTEXITCODE

if ($phaseExitCode -ne 0) {
  throw "Phase 006B V7 failed with exit code $phaseExitCode."
}

Log ""
Log "PHASE 006B REPAIR V10: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006B REPAIR V10: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Diagnostic log: $sessionLog" -ForegroundColor DarkGray
