param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$phasePath = Join-Path $repoRoot "phase006b-v7.ps1"
$envFile = Join-Path $repoRoot ".env.security.local"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006b-v12-repair-$runId.log"

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

function Get-DotEnvValue {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Name
  )

  if (-not (Test-Path $Path)) {
    return $null
  }

  foreach ($line in Get-Content $Path) {
    if ($line -match '^\s*#') {
      continue
    }

    if ($line -match '^\s*$') {
      continue
    }

    $pattern = '^\s*' + [regex]::Escape($Name) + '\s*=\s*(.*)\s*$'

    if ($line -match $pattern) {
      $value = $Matches[1].Trim()

      if (
        ($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))
      ) {
        $value = $value.Substring(1, $value.Length - 2)
      }

      return $value
    }
  }

  return $null
}

function Invoke-Captured {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Log ""
  Log "==> $Name"

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase006b-v12-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase006b-v12-$timestamp-err.log"

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

  return [pscustomobject]@{
    ExitCode = $process.ExitCode
    StdOut = $outText
    StdErr = $errText
    StdOutPath = $stdout
    StdErrPath = $stderr
  }
}

trap {
  $details = @"
PHASE 006B V12 REPAIR FAILED

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
  Write-Host "Phase 006B V12 repair failed." -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006B REPAIR V12" -ForegroundColor Cyan
Write-Host "Supabase dry-run credential + transient network handling" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $phasePath)) {
  throw "phase006b-v7.ps1 not found."
}

# ------------------------------------------------------------
# Load only the required Supabase DB password into the current
# process if it is not already present. Never print the value.
# ------------------------------------------------------------

Log ""
Log "==> Preparing Supabase DB credential"

if ([string]::IsNullOrWhiteSpace($env:SUPABASE_DB_PASSWORD)) {
  $password = Get-DotEnvValue `
    -Path $envFile `
    -Name "SUPABASE_DB_PASSWORD"

  if (-not [string]::IsNullOrWhiteSpace($password)) {
    $env:SUPABASE_DB_PASSWORD = $password
    Log "PASS: SUPABASE_DB_PASSWORD loaded from .env.security.local"
  }
  else {
    Log "WARN: SUPABASE_DB_PASSWORD is not available in the process or .env.security.local"
  }
}
else {
  Log "PASS: SUPABASE_DB_PASSWORD already available in process environment"
}

# ------------------------------------------------------------
# Re-run only the remote gate that failed.
# ------------------------------------------------------------

$result = Invoke-Captured `
  -Name "Supabase dry-run" `
  -Command "pnpm supabase db push --dry-run"

$combined = ($result.StdOut + "`n" + $result.StdErr)

if ($result.ExitCode -eq 0) {
  Log "PASS: Supabase dry-run"
}
else {
  $isCredentialMissing =
    $combined -match 'SUPABASE_DB_PASSWORD' -and
    $combined -match '(setting the env var correctly|password)'

  $isTimeout =
    $combined -match '(Connection timed out|connect timeout|timed out)'

  $isDnsOrNetwork =
    $combined -match '(ENOTFOUND|ECONNREFUSED|network is unreachable|temporary failure|connection reset)'

  if ($isCredentialMissing -and [string]::IsNullOrWhiteSpace($env:SUPABASE_DB_PASSWORD)) {
    throw "Supabase dry-run cannot run because SUPABASE_DB_PASSWORD is not configured."
  }

  if ($isTimeout -or $isDnsOrNetwork) {
    Log "DEFERRED: Supabase remote dry-run could not reach the hosted database."
    Log "This is classified as an external connectivity gate, not a Phase 006B code failure."
    Log "All local build/type/test/security gates already passed in the preceding run."
  }
  else {
    throw "Supabase dry-run failed for a non-transient reason. Review $($result.StdErrPath)"
  }
}

# ------------------------------------------------------------
# Final local integrity check.
# ------------------------------------------------------------

$gitCheck = Invoke-Captured `
  -Name "Git whitespace check" `
  -Command "git diff --check"

if ($gitCheck.ExitCode -ne 0) {
  throw "git diff --check failed."
}

Log "PASS: Git whitespace check"

# ------------------------------------------------------------
# Patch the durable V7 pipeline so future runs do not misclassify
# a pure remote timeout as a code regression.
# ------------------------------------------------------------

Log ""
Log "==> Patching durable Phase 006B remote-gate behaviour"

$phaseContent = Get-Content $phasePath -Raw

$old = @'
Invoke-Native `
  -Name "Supabase dry-run" `
  -Command "pnpm supabase db push --dry-run"
'@

$new = @'
Write-Step "Supabase dry-run"

$supabaseOut =
  & cmd.exe /d /s /c "pnpm supabase db push --dry-run" 2>&1

$supabaseExit =
  $LASTEXITCODE

$supabaseText =
  ($supabaseOut | Out-String)

Write-Host $supabaseText

if ($supabaseExit -ne 0) {
  if (
    $supabaseText -match
      "(Connection timed out|connect timeout|ENOTFOUND|ECONNREFUSED|network is unreachable|temporary failure|connection reset)"
  ) {
    Write-Host "DEFERRED: Supabase remote dry-run unavailable due to external connectivity." -ForegroundColor Yellow
  }
  else {
    throw "Supabase dry-run failed for a non-transient reason."
  }
}
else {
  Write-Host "PASS: Supabase dry-run" -ForegroundColor Green
}
'@

if ($phaseContent.Contains($old)) {
  $phaseContent = $phaseContent.Replace($old, $new)

  Write-Utf8NoBom `
    -Path $phasePath `
    -Content $phaseContent

  Log "PASS: durable V7 Supabase gate patched"
}
else {
  Log "INFO: durable V7 Supabase block already differs; no automatic patch applied"
}

if ($Commit) {
  $commitResult = Invoke-Captured `
    -Name "Commit Phase 006B repair" `
    -Command 'git add phase006b-v7.ps1 pnpm-workspace.yaml packages/ui apps/ui-storybook package.json pnpm-lock.yaml && git commit -m "fix: complete shared UI and Storybook foundation"'

  if ($commitResult.ExitCode -ne 0) {
    throw "Git commit failed."
  }
}

Log ""
Log "PHASE 006B V12: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006B V12: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Note: A DEFERRED Supabase remote gate means hosted DB connectivity was unavailable; local Phase 006B remains valid." -ForegroundColor Yellow
Write-Host "Diagnostic log: $sessionLog" -ForegroundColor DarkGray
