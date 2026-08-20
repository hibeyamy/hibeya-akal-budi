param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$compilerPath = Join-Path $repoRoot "tools\content-compiler\compile.mjs"
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$backupRoot = Join-Path $repoRoot "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  [System.IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Invoke-Native {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Command
  )

  Write-Step $Name

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $stdout = Join-Path $logsRoot "phase005-repair-$timestamp-out.log"
  $stderr = Join-Path $logsRoot "phase005-repair-$timestamp-err.log"

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

  if ($outText) { Write-Host $outText }
  if ($errText) { Write-Host $errText }

  if ($process.ExitCode -ne 0) {
    $diagnostic = Join-Path $logsRoot "FAILED-phase005-repair-$timestamp-$($Name.Replace(' ','-')).log"

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
  Write-Host "PASS: $Name" -ForegroundColor Green
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 005 REPAIR" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $compilerPath)) {
  throw "Compiler not found: $compilerPath"
}

Write-Step "Backing up compiler"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item `
  $compilerPath `
  (Join-Path $backupRoot "$timestamp-tools__content-compiler__compile.mjs") `
  -Force

Write-Step "Repairing activitySource generator"

$compiler = Get-Content $compilerPath -Raw

$pattern = 'const activity =\r?\n\$\{jsonTs\(manifest\.activity\)\}\r?\n  satisfies ActivityContent;'
$replacement = 'const activity:' + "`n" + '  ActivityContent =' + "`n" + '${jsonTs(manifest.activity)};'

$updated = [regex]::Replace(
  $compiler,
  $pattern,
  $replacement
)

if ($updated -eq $compiler) {
  throw "Expected generated ActivityContent pattern was not found. No speculative changes made."
}

Write-Utf8NoBom -Path $compilerPath -Content $updated

Invoke-Native -Name "Compile manifests" -Command "node tools\content-compiler\compile.mjs"
Invoke-Native -Name "Compiler reproducibility" -Command "node tools\content-compiler\compile.mjs --check"
Invoke-Native -Name "Typecheck" -Command "pnpm typecheck"
Invoke-Native -Name "Learner web tests" -Command "pnpm --filter learner-web test"
Invoke-Native -Name "All tests" -Command "pnpm test"
Invoke-Native -Name "Production build" -Command "pnpm build"

if (Test-Path (Join-Path $repoRoot ".env.security.local")) {
  Invoke-Native `
    -Name "RLS security regression" `
    -Command "node --env-file=.env.security.local node_modules/vitest/vitest.mjs run tools/security-tests/rls.integration.test.ts --no-file-parallelism"
}

Invoke-Native -Name "Supabase dry-run" -Command "pnpm supabase db push --dry-run"
Invoke-Native -Name "Git whitespace check" -Command "git diff --check"

if ($Commit) {
  Invoke-Native -Name "Git stage" -Command "git add ."
  Invoke-Native -Name "Git commit" -Command 'git commit -m "fix: stabilise manifest content compiler"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 005 REPAIR: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
