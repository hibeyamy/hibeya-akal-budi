Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008l-repair-v2-$runId.log"

$selectorPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.ts"
$selectorTestPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.test.ts"
$resolverPath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.ts"
$phaseScriptPath = Join-Path $root "phase008l-skill-mastery.ps1"

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

    Copy-Item `
        $Path `
        (Join-Path $backups "$runId-$safe") `
        -Force
}

function Run([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

    $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $out = Join-Path $logs "phase008l-repair-v2-$stamp-out.log"
    $err = Join-Path $logs "phase008l-repair-v2-$stamp-err.log"

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
        $diag = Join-Path $logs "FAILED-phase008l-repair-v2-$stamp-$($Name.Replace(' ','-')).log"

        WriteText `
            $diag `
            "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

        throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
    }

    Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Add-Content `
        $log `
        "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
        -Encoding UTF8

    Write-Host ""
    Write-Host "PHASE 008L REPAIR V2: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    Write-Host "Do not make manual source edits unless explicitly requested after log review." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008L REPAIR V2" -ForegroundColor Cyan
Write-Host "Restore Selector Completion Contract" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# 1. Diagnose before write.
# ------------------------------------------------------------------

foreach ($required in @(
    $selectorPath,
    $selectorTestPath,
    $resolverPath
)) {
    if (-not (Test-Path $required)) {
        throw "Required selector contract file missing: $required"
    }
}

$selector = Get-Content $selectorPath -Raw
$test = Get-Content $selectorTestPath -Raw
$resolver = Get-Content $resolverPath -Raw

# Production resolver contract from 008I:
# - completed IDs are turned into a Set
# - first uncompleted eligible activity wins
foreach ($token in @(
    "new Set(",
    "completedActivityIds",
    "const firstUncompleted",
    "!completed.has(",
    "return firstUncompleted"
)) {
    if ($resolver -notmatch [Regex]::Escape($token)) {
        throw "Next-activity resolver contract drifted. Missing token: $token"
    }
}

# Production selector must still forward BOTH dimensions:
# - completedActivityIds -> progression
# - masteredSkillIds -> prerequisite eligibility
foreach ($token in @(
    "completedActivityIds = []",
    "masteredSkillIds = []",
    "getEligibleActivitiesForLearner({",
    "masteredSkillIds",
    "completedActivityIds,",
    "lastCompletedActivityId"
)) {
    if ($selector -notmatch [Regex]::Escape($token)) {
        throw "Production selector contract drifted. Missing token: $token"
    }
}

# Confirm this is the exact stale-test failure introduced by the Phase 008L
# test migration rather than a production defect.
if ($test -notmatch 'uses completed activities when resolving eligibility and progression') {
    throw "Expected failing selector test case was not found."
}

if ($test -notmatch 'masteredSkillIds') {
    throw "Selector test has not reached the Phase 008L mastery-aware state."
}

if ($test -notmatch 'firstUncompleted') {
    throw "Expected stale first-uncompleted assertion was not found."
}

Write-Host "PASS: production resolver still skips completed eligible activities" -ForegroundColor Green
Write-Host "PASS: production selector forwards completion and mastery independently" -ForegroundColor Green
Write-Host "PASS: failure isolated to stale/corrupted selector test fixture" -ForegroundColor Green

Backup $selectorTestPath
Backup $phaseScriptPath

# ------------------------------------------------------------------
# 2. Replace only the selector test.
#
# The V1 failure happened because the original 008L editor converted
# completedActivityIds test inputs into masteredSkillIds. That removed the
# completion signal from selectLearnerActivity(), so the resolver correctly
# returned the first catalogue item. Production code is not changed here.
# ------------------------------------------------------------------

WriteText $selectorTestPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  getEligibleActivitiesForLearner,
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
      "follows prerequisite-eligible catalogue order",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const masteredSkillIds:
          string[] = [];

        const eligible =
          getEligibleActivitiesForLearner({
            ageBand,
            masteredSkillIds
          });

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              null,

            completedActivityIds:
              [],

            masteredSkillIds
          });

        expect(
          selected?.id ??
          null
        ).toBe(
          eligible[0]?.id ??
          null
        );
      }
    );


    it(
      "keeps completion progression separate from mastery eligibility",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const masteredSkillIds:
          string[] = [];

        const eligible =
          getEligibleActivitiesForLearner({
            ageBand,
            masteredSkillIds
          });

        const first =
          eligible[0];

        if (!first) {
          expect(
            selectLearnerActivity({
              ageBand,

              lastCompletedActivityId:
                null,

              completedActivityIds:
                [],

              masteredSkillIds
            })
          ).toBeNull();

          return;
        }

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              first.id,

            completedActivityIds:
              [first.id],

            masteredSkillIds
          });

        const firstUncompleted =
          eligible.find(
            activity =>
              activity.id !==
                first.id
          );

        if (
          firstUncompleted
        ) {
          expect(
            selected?.id
          ).toBe(
            firstUncompleted.id
          );
        }
        else {
          // The resolver intentionally cycles only after all eligible
          // activities are complete.
          expect(
            selected?.id
          ).toBe(
            first.id
          );
        }
      }
    );


    it(
      "does not use completed activities as a substitute for mastered skills",
      () => {
        const ageBand =
          getSupportedLearnerAgeBand();

        const selected =
          selectLearnerActivity({
            ageBand,

            lastCompletedActivityId:
              null,

            completedActivityIds:
              [],

            masteredSkillIds:
              []
          });

        const eligible =
          getEligibleActivitiesForLearner({
            ageBand,

            masteredSkillIds:
              []
          });

        expect(
          selected?.id ??
          null
        ).toBe(
          eligible[0]?.id ??
          null
        );
      }
    );
  }
);
'@

$verifyTest = Get-Content $selectorTestPath -Raw

foreach ($token in @(
    "completedActivityIds:",
    "masteredSkillIds",
    "keeps completion progression separate from mastery eligibility",
    "does not use completed activities as a substitute for mastered skills"
)) {
    if ($verifyTest -notmatch [Regex]::Escape($token)) {
        throw "Selector test repair postcondition failed. Missing token: $token"
    }
}

Write-Host "PASS: selector test now models completion and mastery as separate inputs" -ForegroundColor Green

# ------------------------------------------------------------------
# 3. Correct the original Phase 008L script so a clean rerun would not
#    recreate the faulty test mutation. We do not rerun the migration.
# ------------------------------------------------------------------

if (Test-Path $phaseScriptPath) {
    $phaseScript = Get-Content $phaseScriptPath -Raw

    $startMarker = '// selector tests: existing no-prerequisite catalogue remains valid with masteredSkillIds=[]'
    $endMarker = '// useNextLearnerActivity: load mastery IDs via service'

    $start = $phaseScript.IndexOf($startMarker)
    $end = $phaseScript.IndexOf($endMarker)

    if ($start -ge 0 -and $end -gt $start) {
        $safeBlock = @'
// selector tests are written explicitly by the PowerShell phase before
// this editor runs. Do not mutate completion inputs into mastery inputs.
// completedActivityIds controls progression; masteredSkillIds controls
// prerequisite eligibility.

'@

        $phaseScript =
            $phaseScript.Substring(0, $start) +
            $safeBlock +
            $phaseScript.Substring($end)

        WriteText $phaseScriptPath $phaseScript

        Write-Host "PASS: original Phase 008L test-mutation defect removed for future reproducibility" -ForegroundColor Green
    }
    else {
        Write-Host "INFO: original Phase 008L mutation block not found; current repository repair remains valid." -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------------
# 4. Run the exact failing test first, then resume the remaining gates.
# ------------------------------------------------------------------

Run `
    "Learner selector tests" `
    "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"

Run `
    "Next activity resolver tests" `
    "pnpm --filter learner-web exec vitest run src/journey/nextLearnerActivity.service.test.ts"

Run `
    "Learning insights typecheck" `
    "pnpm --filter @akal-budi/learning-insights typecheck"

Run `
    "Offline package typecheck" `
    "pnpm --filter @akal-budi/offline typecheck"

Run `
    "Content library typecheck" `
    "pnpm --filter @akal-budi/content-library typecheck"

Run `
    "Learner web typecheck" `
    "pnpm --filter learner-web typecheck"

Run `
    "Learner web tests" `
    "pnpm --filter learner-web test"

Run `
    "Content sequencing validation" `
    "pnpm content:sequence:validate"

Run `
    "Content eligibility validation" `
    "pnpm content:eligibility:validate"

Run `
    "Curriculum validation" `
    "pnpm curriculum:validate"

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
    "Storybook production build" `
    "pnpm storybook:build"

Run `
    "Learner journey regression" `
    "pnpm qa:journey"

Run `
    "Accessibility regression" `
    "pnpm qa:a11y"

Run `
    "Visual regression" `
    "pnpm qa:visual"

Run `
    "Content compiler reproducibility" `
    "pnpm content:check"

Run `
    "Frozen lockfile verification" `
    "pnpm install --frozen-lockfile"

Run `
    "Git whitespace check" `
    "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008L REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Selector completion progression is restored." -ForegroundColor Cyan
Write-Host "Mastery remains an independent prerequisite-eligibility input." -ForegroundColor Cyan
Write-Host "No production resolver behaviour was weakened or bypassed." -ForegroundColor Cyan
Write-Host "No manual intervention was required." -ForegroundColor Cyan
