param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$phasePath = Join-Path $root "phase008e-production-learner-journey.ps1"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008e-repair-v2-$runId.log"

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
  Write-Host "PHASE 008E REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008E REPAIR V2" -ForegroundColor Cyan
Write-Host "Fix PowerShell Backup() method chaining" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $phasePath)) {
  throw "Missing Phase 008E installer: $phasePath"
}

$backup =
  Join-Path `
    $backups `
    "$runId-phase008e-production-learner-journey.ps1"

Copy-Item $phasePath $backup -Force

Write-Host "Backup: $backup" -ForegroundColor Cyan

$source =
  Get-Content `
    $phasePath `
    -Raw

$old = @'
  $relative =
    $Path
      .Substring(
        $root.Length
      )
      .TrimStart("\")

  $safe =
    $relative.Replace(
      "\",
      "__"
    )
'@

$new = @'
  $relative =
    $Path.Substring(
      $root.Length
    ).TrimStart("\")

  $safe =
    $relative.Replace(
      "\",
      "__"
    )
'@

if (
  -not $source.Contains(
    $old
  )
) {
  throw "Expected broken Backup() block was not found. Refusing blind patch."
}

$patched =
  $source.Replace(
    $old,
    $new
  )

WriteText $phasePath $patched

Write-Host "PASS: Backup() method invocation repaired" -ForegroundColor Green

# Parser validation before executing the repaired phase.
$tokens = $null
$errors = $null

[void][System.Management.Automation.Language.Parser]::ParseFile(
  $phasePath,
  [ref]$tokens,
  [ref]$errors
)

if ($errors.Count -gt 0) {
  foreach ($error in $errors) {
    Add-Content $log $error.Message -Encoding UTF8
  }

  throw "Patched Phase 008E failed PowerShell parser validation."
}

Write-Host "PASS: PowerShell parser validation" -ForegroundColor Green

Write-Host ""
Write-Host "==> Re-running Phase 008E" -ForegroundColor Cyan

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

$exitCode =
  $LASTEXITCODE

if (
  $exitCode -ne 0
) {
  throw "Repaired Phase 008E still failed with exit code $exitCode. Review tools\dev\logs\phase008e-*.log"
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008E REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
