param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

$testPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.test.ts"
$selectorPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.ts"
$deviceServicePath = Join-Path $root "apps\learner-web\src\services\deviceActivationService.ts"
$contentIndexPath = Join-Path $root "packages\content-library\src\index.ts"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008i-repair-v3-$runId.log"

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
  $safe = $relative -replace '[\\/:*?"<>|]', '_'
  Copy-Item $Path (Join-Path $backups "$runId-$safe") -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008i-repair-v3-$stamp-out.log"
  $err = Join-Path $logs "phase008i-repair-v3-$stamp-err.log"

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
    $diag = Join-Path $logs "FAILED-phase008i-repair-v3-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008I REPAIR V3: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  Write-Host "Do not make manual source edits unless explicitly requested after log review." -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008I REPAIR V3" -ForegroundColor Cyan
Write-Host "Build-contract-safe selector tests" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($required in @(
  $testPath,
  $selectorPath,
  $deviceServicePath,
  $contentIndexPath
)) {
  if (-not (Test-Path $required)) {
    throw "Required file missing: $required"
  }
}

$testSource = Get-Content $testPath -Raw
$deviceSource = Get-Content $deviceServicePath -Raw
$contentIndex = Get-Content $contentIndexPath -Raw

# Exact diagnosis from the failed production build:
# selector tests use "4-6", but the current LearnerAgeBand contract is
# 2-3 | 3-4 | 4-5 | 5-6. Also, test literals should not encode content age bands.
if ($testSource -notmatch '"4-6"') {
  throw "Expected invalid 4-6 test literal is not present. Refusing blind patch."
}

foreach ($ageBand in @("2-3","3-4","4-5","5-6")) {
  if ($deviceSource -notmatch [Regex]::Escape('"' + $ageBand + '"')) {
    throw "Current LearnerAgeBand contract drifted. Missing expected age band: $ageBand"
  }
}

if ($contentIndex -notmatch "playableActivities") {
  throw "content-library no longer exports playableActivities; cannot build data-driven selector tests safely."
}

Write-Host "PASS: production-build TypeScript failure contract verified" -ForegroundColor Green
Write-Host "PASS: current LearnerAgeBand union verified" -ForegroundColor Green
Write-Host "PASS: content catalogue export available for data-driven tests" -ForegroundColor Green

Backup $testPath

# Replace the test with a catalogue-driven version.
# It discovers a supported age band from current content instead of hard-coding one.
WriteText $testPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  getPlayableActivitiesForAgeBand,
  playableActivities
} from "@akal-budi/content-library";

import type {
  LearnerAgeBand
} from "../../services/deviceActivationService";

import {
  selectLearnerActivity
} from "./selectLearnerActivity";

function getSupportedLearnerAgeBand():
  LearnerAgeBand {
  const candidate =
    playableActivities
      .flatMap(
        activity =>
          activity.ageBands
      )
      .find(
        (
          ageBand
        ): ageBand is LearnerAgeBand =>
          ageBand ===
            "2-3" ||
          ageBand ===
            "3-4" ||
          ageBand ===
            "4-5" ||
          ageBand ===
            "5-6"
      );

  if (!candidate) {
    throw new Error(
      "No playable learner age band is available in the current catalogue."
    );
  }

  return candidate;
}

describe(
  "selectLearnerActivity",
  () => {
    it(
      "follows the playable catalogue order",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const catalogue =
          getPlayableActivitiesForAgeBand(
            ageBand
          );

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              null,

            completedActivityIds:
              []
          });

        expect(
          selected?.id ??
          null
        ).toBe(
          catalogue[0]?.id ??
          null
        );
      }
    );

    it(
      "skips catalogue activities already completed",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const catalogue =
          getPlayableActivitiesForAgeBand(
            ageBand
          );

        const first =
          catalogue[0];

        expect(
          first
        ).toBeDefined();

        if (!first) {
          return;
        }

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              first.id,

            completedActivityIds:
              [first.id]
          });

        if (
          catalogue.length >
          1
        ) {
          expect(
            selected?.id
          ).not.toBe(
            first.id
          );
        }
        else {
          expect(
            selected?.id
          ).toBe(
            first.id
          );
        }
      }
    );
  }
);
'@

$verify = Get-Content $testPath -Raw

if ($verify -match '"4-6"') {
  throw "Invalid 4-6 age-band literal remains after repair."
}

foreach ($requiredToken in @(
  "getSupportedLearnerAgeBand",
  "playableActivities",
  "LearnerAgeBand",
  "selectLearnerActivity"
)) {
  if ($verify -notmatch [Regex]::Escape($requiredToken)) {
    throw "Selector test postcondition failed. Missing: $requiredToken"
  }
}

Write-Host "PASS: selector tests are now catalogue-driven and build-contract-safe" -ForegroundColor Green

# Crucially, run the exact build command that failed BEFORE the broader suite.
Run `
  "Learner production build" `
  "pnpm --filter learner-web build"

Run `
  "Selector tests" `
  "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"

Run `
  "Learner web typecheck" `
  "pnpm --filter learner-web typecheck"

Run `
  "Learner web tests" `
  "pnpm --filter learner-web test"

Run `
  "Focused home continue journey E2E" `
  'pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-journey.spec.ts -g "home continue opens an activity and exit returns home"'

Run `
  "Learner journey E2E" `
  "pnpm qa:journey"

Run `
  "Repository typecheck" `
  "pnpm typecheck"

Run `
  "All tests" `
  "pnpm test"

Run `
  "Full production build" `
  "pnpm build"

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

if ($Commit) {
  Run `
    "Stage Phase 008I Repair V3" `
    "git add apps/learner-web/src/features/play/selectLearnerActivity.test.ts"

  Run `
    "Commit Phase 008I Repair V3" `
    'git commit -m "test: derive selector age band from catalogue"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008I REPAIR V3: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No manual intervention was required." -ForegroundColor Cyan
Write-Host "Production resume architecture remains modular and unchanged." -ForegroundColor Cyan
