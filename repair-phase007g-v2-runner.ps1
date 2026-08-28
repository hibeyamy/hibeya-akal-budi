param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$phase = Join-Path $root "phase007g-v2-production-visual-alignment.ps1"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007g-v2-repair-$runId.log"

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

function Invoke-Native([string]$Name,[string]$Command) {
  Log ""
  Log "==> $Name"
  Log "COMMAND: $Command"

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logs "phase007g-v2-repair-$stamp-out.log"
  $stderr = Join-Path $logs "phase007g-v2-repair-$stamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -NoNewWindow `
    -Wait `
    -PassThru

  $outText = if (Test-Path $stdout) { Get-Content $stdout -Raw } else { "" }
  $errText = if (Test-Path $stderr) { Get-Content $stderr -Raw } else { "" }

  if ($outText) {
    Write-Host $outText
    Add-Content -Path $log -Value $outText -Encoding UTF8
  }

  if ($errText) {
    Write-Host $errText
    Add-Content -Path $log -Value $errText -Encoding UTF8
  }

  if ($process.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase007g-v2-repair-$stamp-$($Name.Replace(' ','-')).log"

    WriteText $diag @"
COMMAND:
$Command

EXIT CODE:
$($process.ExitCode)

STDOUT:
$outText

STDERR:
$errText
"@

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
  Log "PASS: $Name"
}

trap {
  WriteText $log @"
PHASE 007G V2 REPAIR FAILED

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
  Write-Host "PHASE 007G V2 REPAIR: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007G V2 REPAIR" -ForegroundColor Cyan
Write-Host "PowerShell-native process handling fix" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $phase)) {
  throw "Phase 007G V2 installer not found: $phase"
}

# Confirm the underlying audit genuinely passes before touching the runner.
Invoke-Native `
  "Six-asset production visual audit" `
  "pnpm assets:visual-baseline:audit"

# Backup and patch only the Run() implementation.
$backup = Join-Path $backups "$runId-phase007g-v2-production-visual-alignment.ps1"
Copy-Item $phase $backup -Force
Log "Backup: $backup"

$source = Get-Content $phase -Raw

$oldRunPattern = '(?s)function Run\(\[string\]\$Name,\[string\]\$Command\) \{.*?\n\}\n\ntrap \{'

$newRun = @'
function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase007g-v2-$stamp-out.log"
  $err = Join-Path $logs "phase007g-v2-$stamp-err.log"

  $p = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $o = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $e = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($o) {
    Write-Host $o
    Add-Content $log $o -Encoding UTF8
  }

  if ($e) {
    Write-Host $e
    Add-Content $log $e -Encoding UTF8
  }

  if ($p.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase007g-v2-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"

    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
'@

$updated = [regex]::Replace(
  $source,
  $oldRunPattern,
  $newRun,
  1
)

if ($updated -eq $source) {
  if ($source -match 'Start-Process\s+`[\s\S]*?RedirectStandardOutput') {
    Log "PASS: Phase 007G V2 runner already uses safe native process handling"
  }
  else {
    throw "Could not safely locate the legacy Run() function."
  }
}
else {
  WriteText $phase $updated
  Log "PASS: Phase 007G V2 runner upgraded"
}

# Re-run complete phase. Artwork will be deterministically re-emitted with same content.
Log ""
Log "==> Re-running complete Phase 007G V2"

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
  throw "Phase 007G V2 still failed with exit code $LASTEXITCODE."
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007G V2 REPAIR: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next manual step:" -ForegroundColor Cyan
Write-Host "  pnpm storybook" -ForegroundColor White
Write-Host "Open: Assets -> Production Visual Baseline -> Six Asset Audit" -ForegroundColor White
