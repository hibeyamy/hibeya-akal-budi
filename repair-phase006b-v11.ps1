param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$phasePath = Join-Path $repoRoot "phase006b-v7.ps1"
$uiIndexPath = Join-Path $repoRoot "packages\ui\src\index.ts"
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$backupRoot = Join-Path $repoRoot "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006b-v11-repair-$runId.log"

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

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Log ""
  Log "==> $Name"

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase006b-v11-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase006b-v11-$timestamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d", "/s", "/c", $Command) `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -NoNewWindow `
    -Wait `
    -PassThru

  $outText = if (Test-Path $stdout) { Get-Content $stdout -Raw } else { "" }
  $errText = if (Test-Path $stderr) { Get-Content $stderr -Raw } else { "" }

  if ($outText) {
    Write-Host $outText
    Add-Content -Path $sessionLog -Value $outText -Encoding UTF8
  }

  if ($errText) {
    Write-Host $errText
    Add-Content -Path $sessionLog -Value $errText -Encoding UTF8
  }

  if ($process.ExitCode -ne 0) {
    $diagnostic = Join-Path $logsRoot "FAILED-phase006b-v11-$timestamp-$($Name.Replace(' ','-')).log"

    Write-Utf8NoBom `
      -Path $diagnostic `
      -Content @"
COMMAND:
$Command

EXIT CODE:
$($process.ExitCode)

STDOUT:
$outText

STDERR:
$errText
"@

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diagnostic"
  }

  Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue

  Log "PASS: $Name"
}

trap {
  $details = @"
PHASE 006B V11 REPAIR FAILED

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
  Write-Host "Phase 006B V11 repair failed." -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006B REPAIR V11" -ForegroundColor Cyan
Write-Host "Remove CSS side-effect import from package entrypoint" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $phasePath)) {
  throw "phase006b-v7.ps1 not found in repository root."
}

if (-not (Test-Path $uiIndexPath)) {
  throw "packages\ui\src\index.ts not found."
}

# ------------------------------------------------------------
# Back up both the durable installer and current generated file.
# ------------------------------------------------------------

Log ""
Log "==> Backing up files"

Copy-Item `
  $phasePath `
  (Join-Path $backupRoot "$runId-phase006b-v7.ps1") `
  -Force

Copy-Item `
  $uiIndexPath `
  (Join-Path $backupRoot "$runId-packages__ui__src__index.ts") `
  -Force

Log "PASS: backups created"

# ------------------------------------------------------------
# Fix the architecture:
# package entrypoints should not force-import CSS.
# Consumers import @akal-budi/ui/styles.css once at app level.
# Storybook already does this in preview.ts.
# ------------------------------------------------------------

Log ""
Log "==> Removing CSS side-effect import from current UI entrypoint"

$currentIndex = Get-Content $uiIndexPath -Raw

$currentIndex = [regex]::Replace(
  $currentIndex,
  '^\s*import\s+["'']\.\/styles\.css["''];\s*\r?\n\r?\n?',
  '',
  [System.Text.RegularExpressions.RegexOptions]::Multiline
)

Write-Utf8NoBom `
  -Path $uiIndexPath `
  -Content $currentIndex

Log "PASS: current UI entrypoint fixed"

Log ""
Log "==> Patching Phase 006B V7 generator permanently"

$phaseContent = Get-Content $phasePath -Raw

$oldLiteral = @'
$uiIndex = @'
import "./styles.css";

export { AudienceShell } from "./AudienceShell";
'@

$newLiteral = @'
$uiIndex = @'
export { AudienceShell } from "./AudienceShell";
'@

if ($phaseContent.Contains($oldLiteral)) {
  $phaseContent = $phaseContent.Replace($oldLiteral, $newLiteral)
}
else {
  # Safe fallback: remove only the exact generated CSS side-effect line
  # inside the UI index here-string.
  $updated = [regex]::Replace(
    $phaseContent,
    '(\$uiIndex\s*=\s*@''\r?\n)\s*import\s+["'']\.\/styles\.css["''];\s*\r?\n\r?\n?',
    '$1'
  )

  if ($updated -eq $phaseContent) {
    throw "Could not locate the UI index CSS side-effect import in phase006b-v7.ps1."
  }

  $phaseContent = $updated
}

Write-Utf8NoBom `
  -Path $phasePath `
  -Content $phaseContent

Log "PASS: Phase 006B V7 generator patched"

# ------------------------------------------------------------
# Verify immediate gates first.
# ------------------------------------------------------------

Invoke-Native `
  -Name "UI package typecheck" `
  -Command "pnpm --filter @akal-budi/ui typecheck"

Invoke-Native `
  -Name "Storybook typecheck" `
  -Command "pnpm --filter ui-storybook typecheck"

# ------------------------------------------------------------
# Re-run full durable Phase 006B pipeline.
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
Log "PHASE 006B REPAIR V11: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006B REPAIR V11: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Diagnostic log: $sessionLog" -ForegroundColor DarkGray
