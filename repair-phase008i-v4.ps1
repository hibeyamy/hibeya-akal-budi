param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"

$storybookStatic = Join-Path $root "apps\ui-storybook\storybook-static"
$storybookIndex = Join-Path $storybookStatic "index.json"
$storybookIframe = Join-Path $storybookStatic "iframe.html"
$journeyTest = Join-Path $root "tools\visual-regression\tests\learner-journey.spec.ts"

New-Item -ItemType Directory -Force -Path $logs | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008i-repair-v4-$runId.log"

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

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008i-repair-v4-$stamp-out.log"
  $err = Join-Path $logs "phase008i-repair-v4-$stamp-err.log"

  $p = Start-Process `
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

  if ($p.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase008i-repair-v4-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

function Assert-StorybookStatic {
  if (-not (Test-Path $storybookIndex)) {
    throw "Storybook static index is missing: $storybookIndex"
  }

  if (-not (Test-Path $storybookIframe)) {
    throw "Storybook iframe is missing: $storybookIframe"
  }

  $json = Get-Content $storybookIndex -Raw | ConvertFrom-Json
  $entries = @($json.entries.PSObject.Properties | ForEach-Object { $_.Value })

  $journey = $entries | Where-Object {
    $_.id -eq "learner-journey--default"
  } | Select-Object -First 1

  if (-not $journey) {
    throw "Storybook index does not contain learner-journey--default."
  }

  Write-Host "PASS: Storybook static output contains learner-journey--default" -ForegroundColor Green
}

trap {
  Add-Content `
    $log `
    "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
    -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008I REPAIR V4: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  Write-Host "Do not make manual source edits unless explicitly requested after log review." -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008I REPAIR V4" -ForegroundColor Cyan
Write-Host "Restore Storybook static output before journey E2E" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $journeyTest)) {
  throw "Missing journey Playwright test: $journeyTest"
}

# The previous failed monorepo build started Storybook concurrently, cleaned
# storybook-static, and was then aborted when learner-web failed. V3 subsequently
# ran Playwright without rebuilding Storybook, so the iframe returned non-2xx.
Write-Host "Diagnosis: stale/incomplete Storybook static output after interrupted monorepo build." -ForegroundColor Cyan
Write-Host "No source-code repair is required for the modular resume architecture." -ForegroundColor Cyan

# Rebuild the exact dependency required by qa:journey.
Run `
  "Storybook production build" `
  "pnpm storybook:build"

Assert-StorybookStatic

# Run the previously failing boundary immediately after a verified Storybook build.
Run `
  "Focused home continue journey E2E" `
  'pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-journey.spec.ts -g "home continue opens an activity and exit returns home"'

Run `
  "Full learner journey E2E" `
  "pnpm qa:journey"

# Validate the already-fixed selector/build contract.
Run `
  "Learner production build" `
  "pnpm --filter learner-web build"

Run `
  "Learner web typecheck" `
  "pnpm --filter learner-web typecheck"

Run `
  "Learner web tests" `
  "pnpm --filter learner-web test"

Run `
  "Repository typecheck" `
  "pnpm typecheck"

Run `
  "All tests" `
  "pnpm test"

# Full build may clean/rebuild Storybook again. Since the earlier failure was
# caused by an interrupted concurrent Storybook build, verify this gate fully.
Run `
  "Full production build" `
  "pnpm build"

# Re-establish and verify Storybook static state after the monorepo build before
# all browser-based Storybook QA.
Run `
  "Post-build Storybook production build" `
  "pnpm storybook:build"

Assert-StorybookStatic

Run `
  "Post-build learner journey E2E" `
  "pnpm qa:journey"

Run `
  "Accessibility regression" `
  "pnpm qa:a11y"

Run `
  "Visual regression" `
  "pnpm qa:visual"

Run `
  "Content compiler check" `
  "pnpm content:check"

Run `
  "Curriculum validation" `
  "pnpm curriculum:validate"

Run `
  "Git whitespace check" `
  "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008I REPAIR V4: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No manual intervention was required." -ForegroundColor Cyan
Write-Host "No application source files were modified." -ForegroundColor Cyan
Write-Host "Modular resume architecture remains intact." -ForegroundColor Cyan
