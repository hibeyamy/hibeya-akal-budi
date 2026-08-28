param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008i-repair-v2-$runId.log"

$storyPath = Join-Path $root "apps\ui-storybook\stories\LearnerJourney.stories.tsx"
$offlineIndex = Join-Path $root "packages\offline\src\index.ts"
$activityPath = Join-Path $root "packages\content-library\src\activities\warna-merah-001.ts"

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
  $safe = $relative -replace '[\\/:*?"<>|]', '_'
  Copy-Item $Path (Join-Path $backups "$runId-$safe") -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008i-repair-v2-$stamp-out.log"
  $err = Join-Path $logs "phase008i-repair-v2-$stamp-err.log"

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
    $diag = Join-Path $logs "FAILED-phase008i-repair-v2-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 008I REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  Write-Host "Do not make manual source edits unless explicitly requested after this log is reviewed." -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008I REPAIR V2" -ForegroundColor Cyan
Write-Host "Deterministic Storybook learner context fixture" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($required in @(
  $storyPath,
  $offlineIndex,
  $activityPath
)) {
  if (-not (Test-Path $required)) {
    throw "Required file missing: $required"
  }
}

$storySource = Get-Content $storyPath -Raw
$offlineSource = Get-Content $offlineIndex -Raw
$activitySource = Get-Content $activityPath -Raw

# Diagnose the exact failure contract before editing:
# - production hook correctly needs persisted learner profile
# - Storybook story currently renders screen without seeding one
foreach ($token in @(
  "LearnerJourneyScreen",
  "export function Default"
)) {
  if ($storySource -notmatch [Regex]::Escape($token)) {
    throw "Storybook journey contract drifted. Missing token: $token"
  }
}

foreach ($token in @(
  "saveLearnerRuntimeProfile",
  "clearLearnerJourneyState"
)) {
  if ($offlineSource -notmatch [Regex]::Escape($token)) {
    throw "Offline fixture API unavailable. Missing export: $token"
  }
}

# Use a real supported catalogue age band, verified from current activity source.
$ageBandMatch = [Regex]::Match(
  $activitySource,
  '"ageBand"\s*:\s*"([^"]+)"'
)

if (-not $ageBandMatch.Success) {
  throw "Could not discover a supported age band from current content."
}

$fixtureAgeBand = $ageBandMatch.Groups[1].Value

if ([string]::IsNullOrWhiteSpace($fixtureAgeBand)) {
  throw "Discovered fixture age band is empty."
}

Write-Host "PASS: diagnosed Storybook-only missing learner profile context" -ForegroundColor Green
Write-Host "PASS: discovered supported fixture age band: $fixtureAgeBand" -ForegroundColor Green

Backup $storyPath

# Build the Storybook fixture dynamically so no activity ID is hard-coded.
$storyTemplate = @'
import {
  useEffect,
  useState
} from "react";

import {
  clearLearnerJourneyState,
  saveLearnerRuntimeProfile
} from "../../../packages/offline/src";

import {
  LearnerJourneyScreen
} from "../../learner-web/src/journey";

export default {
  title:
    "Learner/Journey"
};

function DeterministicLearnerJourneyFixture() {
  const [
    ready,
    setReady
  ] =
    useState(false);

  useEffect(
    () => {
      let mounted =
        true;

      void (
        async () => {
          await clearLearnerJourneyState();

          await saveLearnerRuntimeProfile({
            childId:
              "storybook-child",

            ageBand:
              "__FIXTURE_AGE_BAND__",

            preferredLanguage:
              "ms",

            validatedAt:
              1
          });

          if (
            mounted
          ) {
            setReady(
              true
            );
          }
        }
      )();

      return () => {
        mounted =
          false;
      };
    },
    []
  );

  if (
    !ready
  ) {
    return (
      <main
        aria-busy="true"
        className="p-6"
      >
        Menyediakan profil pembelajaran...
      </main>
    );
  }

  return (
    <LearnerJourneyScreen />
  );
}

export function Default() {
  return (
    <DeterministicLearnerJourneyFixture />
  );
}
'@

$storyContent = $storyTemplate.Replace(
  "__FIXTURE_AGE_BAND__",
  $fixtureAgeBand
)

WriteText $storyPath $storyContent

$verify = Get-Content $storyPath -Raw

foreach ($requiredToken in @(
  "saveLearnerRuntimeProfile",
  "clearLearnerJourneyState",
  "DeterministicLearnerJourneyFixture",
  $fixtureAgeBand
)) {
  if ($verify -notmatch [Regex]::Escape($requiredToken)) {
    throw "Storybook fixture postcondition failed. Missing: $requiredToken"
  }
}

if ($verify -match 'warna-(merah|bunga-raya)-001') {
  throw "Activity-specific ID was introduced into Storybook fixture."
}

Write-Host "PASS: deterministic learner profile fixture installed" -ForegroundColor Green
Write-Host "PASS: no activity-specific content ID introduced" -ForegroundColor Green
Write-Host "PASS: production learner runtime code remains unchanged" -ForegroundColor Green

# Validate the smallest failing boundary first.
Run `
  "Storybook typecheck" `
  "pnpm --filter ui-storybook typecheck"

Run `
  "Storybook production build" `
  "pnpm storybook:build"

Run `
  "Focused home continue journey E2E" `
  'pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-journey.spec.ts -g "home continue opens an activity and exit returns home"'

# Then full regression.
Run `
  "Learner journey E2E" `
  "pnpm qa:journey"

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

Run `
  "Production build" `
  "pnpm build"

Run `
  "Accessibility regression" `
  "pnpm qa:a11y"

Run `
  "Visual regression" `
  "pnpm qa:visual"

Run `
  "Git whitespace check" `
  "git diff --check"

if ($Commit) {
  Run `
    "Stage Phase 008I Repair V2" `
    "git add apps/ui-storybook/stories/LearnerJourney.stories.tsx"

  Run `
    "Commit Phase 008I Repair V2" `
    'git commit -m "test: seed deterministic learner context in journey story"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008I REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The modular production resume architecture is preserved." -ForegroundColor Cyan
Write-Host "Storybook now supplies the learner profile fixture that production activation normally persists." -ForegroundColor Cyan
Write-Host "No manual intervention was required." -ForegroundColor Cyan
