param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

$storybookEnv = Join-Path $root "apps\ui-storybook\.env"
$supabaseSource = Join-Path $root "apps\learner-web\src\lib\supabase.ts"
$journeyTest = Join-Path $root "tools\visual-regression\tests\learner-journey.spec.ts"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008f-repair-v3-$runId.log"

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
  if (-not (Test-Path $Path)) { return }

  $relative = $Path.Substring($root.Length).TrimStart("\")
  $safe = $relative.Replace("\","__")

  Copy-Item $Path (Join-Path $backups "$runId-$safe") -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008f-repair-v3-$stamp-out.log"
  $err = Join-Path $logs "phase008f-repair-v3-$stamp-err.log"

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

  if ($stdout) { Write-Host $stdout; Add-Content $log $stdout -Encoding UTF8 }
  if ($stderr) { Write-Host $stderr; Add-Content $log $stderr -Encoding UTF8 }

  if ($process.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase008f-repair-v3-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"
    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 008F REPAIR V3: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008F REPAIR V3" -ForegroundColor Cyan
Write-Host "Isolated Storybook Supabase environment" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $supabaseSource)) {
  throw "Missing learner Supabase module: $supabaseSource"
}

if (-not (Test-Path $journeyTest)) {
  throw "Missing learner journey Playwright suite: $journeyTest"
}

$supabaseText = Get-Content $supabaseSource -Raw

foreach ($required in @("VITE_SUPABASE_URL","VITE_SUPABASE_ANON_KEY")) {
  if ($supabaseText -notmatch [Regex]::Escape($required)) {
    throw "Supabase source contract drifted. Missing expected token: $required"
  }
}

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
    throw "Latest Phase 008F V2 failure does not match the diagnosed Supabase environment error. Refusing blind repair."
  }

  Write-Host "PASS: latest failure confirms Missing VITE_SUPABASE_URL" -ForegroundColor Green
}
else {
  Write-Host "INFO: no local V2 failure log found; continuing from verified source contract." -ForegroundColor Yellow
}

Backup $storybookEnv

$existing = if (Test-Path $storybookEnv) { Get-Content $storybookEnv -Raw } else { "" }
$lines = if ($existing) { $existing -split "`r?`n" } else { @() }

$filtered =
  $lines |
  Where-Object {
    $_ -notmatch "^\s*VITE_SUPABASE_URL\s*=" -and
    $_ -notmatch "^\s*VITE_SUPABASE_ANON_KEY\s*="
  }

$envContent =
  @(
    "# Storybook-only deterministic environment."
    "# Never points to hosted production data."
    "VITE_SUPABASE_URL=http://127.0.0.1:54321"
    "VITE_SUPABASE_ANON_KEY=storybook-local-placeholder-key"
    ""
    $filtered
  ) -join "`n"

WriteText $storybookEnv $envContent

$written = Get-Content $storybookEnv -Raw

if ($written -notmatch "VITE_SUPABASE_URL=http://127\.0\.0\.1:54321") {
  throw "Storybook Supabase URL postcondition failed."
}

if ($written -notmatch "VITE_SUPABASE_ANON_KEY=storybook-local-placeholder-key") {
  throw "Storybook Supabase key postcondition failed."
}

Write-Host "PASS: Storybook environment is local-only and deterministic" -ForegroundColor Green

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
    "Stage Phase 008F Repair V3" `
    "git add -f apps/ui-storybook/.env && git add tools/visual-regression/tests/learner-journey.spec.ts package.json"

  Run `
    "Commit Phase 008F Repair V3" `
    'git commit -m "test: isolate storybook learner runtime environment"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008F REPAIR V3: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Storybook learner runtime now uses local-only placeholder Supabase configuration." -ForegroundColor Cyan
Write-Host "Production Supabase configuration was not modified." -ForegroundColor Cyan
