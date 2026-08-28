param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$workspacePath = Join-Path $repoRoot "pnpm-workspace.yaml"
$phasePath = Join-Path $repoRoot "phase006b-v7.ps1"
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$backupRoot = Join-Path $repoRoot "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006b-v8-repair-$runId.log"

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $directory = Split-Path -Parent $Path

  if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
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

  Add-Content `
    -Path $sessionLog `
    -Value $Message `
    -Encoding UTF8
}

trap {
  $details = @"
PHASE 006B V8 REPAIR FAILED

TIME:
$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")

MESSAGE:
$($_.Exception.Message)

ERROR RECORD:
$($_ | Out-String)

POSITION:
$($_.InvocationInfo.PositionMessage)

SCRIPT STACK:
$($_.ScriptStackTrace)
"@

  Write-Utf8NoBom -Path $sessionLog -Content $details

  Write-Host ""
  Write-Host "Repair failed." -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow

  exit 1
}


Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006B REPAIR V8" -ForegroundColor Cyan
Write-Host "Approve required esbuild lifecycle script safely" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"


if (-not (Test-Path $workspacePath)) {
  throw "pnpm-workspace.yaml not found."
}

if (-not (Test-Path $phasePath)) {
  throw "phase006b-v7.ps1 not found. Keep the V7 installer in the repository root for this repair."
}


# ------------------------------------------------------------
# Back up current pnpm-workspace.yaml.
# ------------------------------------------------------------

Log ""
Log "==> Backing up pnpm-workspace.yaml"

$backupPath =
  Join-Path `
    $backupRoot `
    "$runId-pnpm-workspace.yaml"

Copy-Item `
  $workspacePath `
  $backupPath `
  -Force

Log "Backup: $backupPath"


# ------------------------------------------------------------
# pnpm 11 has strict dependency-build protection by default.
# Storybook pulled esbuild, whose postinstall is required.
# We explicitly allow esbuild and nothing else.
#
# This intentionally does NOT use dangerouslyAllowAllBuilds.
# ------------------------------------------------------------

Log ""
Log "==> Ensuring allowBuilds.esbuild = true"

$content =
  Get-Content `
    $workspacePath `
    -Raw

# Normalise only in memory for deterministic line-based editing.
$lines =
  $content -split "\r?\n"

$allowBuildsIndex =
  -1

for (
  $i = 0;
  $i -lt $lines.Count;
  $i++
) {
  if (
    $lines[$i] -match
    '^\s*allowBuilds\s*:\s*$'
  ) {
    $allowBuildsIndex =
      $i

    break
  }
}


if (
  $allowBuildsIndex -ge 0
) {
  $nextTopLevelIndex =
    $lines.Count

  for (
    $i =
      $allowBuildsIndex + 1;
    $i -lt $lines.Count;
    $i++
  ) {
    if (
      $lines[$i] -match
      '^[A-Za-z0-9_-][A-Za-z0-9_-]*\s*:'
  ) {
    $nextTopLevelIndex =
      $i

    break
  }

  $esbuildIndex =
    -1

  for (
    $i =
      $allowBuildsIndex + 1;
    $i -lt $nextTopLevelIndex;
    $i++
  ) {
    if (
      $lines[$i] -match
      '^\s+["'']?esbuild(?:@[^"'']+)?["'']?\s*:'
    ) {
      $esbuildIndex =
        $i

      break
    }
  }

  if (
    $esbuildIndex -ge 0
  ) {
    $lines[$esbuildIndex] =
      "  esbuild: true"

    Log "Updated existing esbuild build approval."
  }
  else {
    $before =
      @(
        $lines[
          0..$allowBuildsIndex
        ]
      )

    $after =
      if (
        $allowBuildsIndex + 1 -lt
        $lines.Count
      ) {
        @(
          $lines[
            ($allowBuildsIndex + 1)..
            ($lines.Count - 1)
          ]
        )
      }
      else {
        @()
      }

    $lines =
      @(
        $before +
        "  esbuild: true" +
        $after
      )

    Log "Added esbuild build approval."
  }
}
else {
  $trimmed =
    $content.TrimEnd()

  $content =
    $trimmed +
    "`n`nallowBuilds:`n  esbuild: true`n"

  $lines =
    $content -split "\r?\n"

  Log "Created allowBuilds block with esbuild approval."
}


$newContent =
  (
    $lines -join "`n"
  ).TrimEnd() +
  "`n"

Write-Utf8NoBom `
  -Path $workspacePath `
  -Content $newContent


# ------------------------------------------------------------
# Verify exactly the intended setting exists.
# ------------------------------------------------------------

Log ""
Log "==> Verifying pnpm build approval policy"

$verifyText =
  Get-Content `
    $workspacePath `
    -Raw

if (
  $verifyText -notmatch
  '(?ms)^allowBuilds\s*:\s*\r?\n(?:[ \t]+.*\r?\n)*?[ \t]+esbuild\s*:\s*true\s*$'
) {
  throw "Could not verify allowBuilds -> esbuild: true in pnpm-workspace.yaml."
}

if (
  $verifyText -match
  '(?m)^\s*dangerouslyAllowAllBuilds\s*:\s*true\s*$'
) {
  throw "Unsafe setting detected: dangerouslyAllowAllBuilds: true. Repair stopped."
}

Log "PASS: esbuild is explicitly allowed; global build-script approval is not enabled."


# ------------------------------------------------------------
# Re-run install once so esbuild's required postinstall executes.
# ------------------------------------------------------------

Log ""
Log "==> Rebuilding/installing dependencies under approved policy"

& pnpm install

if (
  $LASTEXITCODE -ne 0
) {
  throw "pnpm install failed after esbuild approval."
}

Log "PASS: pnpm install"


# ------------------------------------------------------------
# Run the complete Phase 006B V7 pipeline again.
# ------------------------------------------------------------

Log ""
Log "==> Re-running complete Phase 006B V7 pipeline"

$arguments =
  @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $phasePath
  )

if ($Commit) {
  $arguments +=
    "-Commit"
}

& powershell.exe @arguments

$exitCode =
  $LASTEXITCODE

if (
  $exitCode -ne 0
) {
  throw "Phase 006B V7 still failed with exit code $exitCode. Review its generated log plus $sessionLog."
}


Log ""
Log "PHASE 006B REPAIR V8: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006B REPAIR V8: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Diagnostic log: $sessionLog" -ForegroundColor DarkGray
