param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

$supabaseSource = Join-Path $root "apps\learner-web\src\lib\supabase.ts"
$storybookEnv = Join-Path $root "apps\ui-storybook\.env"
$journeyTest = Join-Path $root "tools\visual-regression\tests\learner-journey.spec.ts"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008f-repair-v4-$runId.log"

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

function Backup([string]$Path) {
  if (-not (Test-Path $Path)) {
    return
  }

  $relative = $Path.Substring($root.Length).TrimStart("\")
  $safe = $relative.Replace("\","__")

  Copy-Item $Path (Join-Path $backups "$runId-$safe") -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008f-repair-v4-$stamp-out.log"
  $err = Join-Path $logs "phase008f-repair-v4-$stamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $stdout = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $stderr = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($stdout) {
    Write-Host $stdout
    Add-Content $log $stdout -Encoding UTF8
  }

  if ($stderr) {
    Write-Host $stderr
    Add-Content $log $stderr -Encoding UTF8
  }

  if ($process.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase008f-repair-v4-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008F REPAIR V4: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008F REPAIR V4" -ForegroundColor Cyan
Write-Host "Source-adaptive Storybook Supabase environment" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $supabaseSource)) {
  throw "Missing learner Supabase module: $supabaseSource"
}

if (-not (Test-Path $journeyTest)) {
  throw "Missing learner journey Playwright suite: $journeyTest"
}

# ------------------------------------------------------------------
# 1. Discover the CURRENT Supabase environment contract from source.
#    No hard-coded assumption about ANON vs PUBLISHABLE key names.
# ------------------------------------------------------------------

$supabaseText = Get-Content $supabaseSource -Raw

$matches =
  [Regex]::Matches(
    $supabaseText,
    'VITE_SUPABASE_[A-Z0-9_]+'
  )

$envNames =
  @(
    $matches |
    ForEach-Object { $_.Value } |
    Sort-Object -Unique
  )

if ($envNames.Count -eq 0) {
  throw "No VITE_SUPABASE_* variables were found in current supabase.ts."
}

if ($envNames -notcontains "VITE_SUPABASE_URL") {
  throw "Current supabase.ts does not reference VITE_SUPABASE_URL; refusing to invent a runtime contract."
}

$keyNames =
  @(
    $envNames |
    Where-Object {
      $_ -match 'KEY|ANON|PUBLISHABLE'
    }
  )

if ($keyNames.Count -eq 0) {
  throw "No Supabase key-like VITE_SUPABASE_* variable was discovered in current supabase.ts."
}

Write-Host ""
Write-Host "Discovered Supabase env contract:" -ForegroundColor Cyan

foreach ($name in $envNames) {
  Write-Host "  $name"
  Add-Content $log "DISCOVERED ENV: $name" -Encoding UTF8
}

Write-Host "PASS: current Supabase env contract discovered from source" -ForegroundColor Green

# ------------------------------------------------------------------
# 2. Confirm the prior failure class, but do not require stale key names.
# ------------------------------------------------------------------

$latestFailure =
  Get-ChildItem `
    $logs `
    -Filter "FAILED-phase008f-repair-v2-*-Learner-journey-end-to-end-regression.log" `
    -File `
    -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($latestFailure) {
  $failureText = Get-Content $latestFailure.FullName -Raw

  if ($failureText -notmatch "Missing VITE_SUPABASE_URL") {
    throw "Latest Phase 008F V2 failure is not the diagnosed missing Storybook Supabase environment failure."
  }

  Write-Host "PASS: prior browser failure confirms missing VITE_SUPABASE_URL" -ForegroundColor Green
}

# ------------------------------------------------------------------
# 3. Write Storybook-only deterministic values for exactly the variables
#    discovered from current source. Production configuration is untouched.
# ------------------------------------------------------------------

Backup $storybookEnv

$existingLines =
  if (Test-Path $storybookEnv) {
    @(Get-Content $storybookEnv)
  }
  else {
    @()
  }

$preservedLines =
  @(
    $existingLines |
    Where-Object {
      $_ -notmatch '^\s*VITE_SUPABASE_[A-Z0-9_]+\s*='
    }
  )

$newLines = @(
  "# Storybook-only deterministic Supabase environment."
  "# Local placeholder values; never production credentials."
)

foreach ($name in $envNames) {
  if ($name -eq "VITE_SUPABASE_URL") {
    $newLines += "$name=http://127.0.0.1:54321"
  }
  else {
    $newLines += "$name=storybook-local-placeholder"
  }
}

if ($preservedLines.Count -gt 0) {
  $newLines += ""
  $newLines += $preservedLines
}

WriteText $storybookEnv ($newLines -join "`n")

$written = Get-Content $storybookEnv -Raw

foreach ($name in $envNames) {
  if ($written -notmatch "(?m)^$([Regex]::Escape($name))=") {
    throw "Storybook environment postcondition failed for $name."
  }
}

if ($written -notmatch 'VITE_SUPABASE_URL=http://127\.0\.0\.1:54321') {
  throw "Storybook Supabase URL is not local-only."
}

Write-Host "PASS: Storybook environment generated from current source contract" -ForegroundColor Green

# ------------------------------------------------------------------
# 4. Fast validation first, then full suite.
# ------------------------------------------------------------------

Run "Storybook production build" "pnpm storybook:build"

Run `
  "Learner journey smoke regression" `
  'pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-journey.spec.ts -g "home opens explore and returns home"'

Run "Learner journey end-to-end regression" "pnpm qa:journey"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression" "pnpm qa:visual"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run `
    "Stage Phase 008F Repair V4" `
    "git add -f apps/ui-storybook/.env && git add tools/visual-regression/tests/learner-journey.spec.ts package.json"

  Run `
    "Commit Phase 008F Repair V4" `
    'git commit -m "test: make storybook supabase environment source adaptive"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008F REPAIR V4: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Storybook Supabase variables were derived from current learner source." -ForegroundColor Cyan
Write-Host "No production credential names were assumed." -ForegroundColor Cyan
