param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$journeyRoot = Join-Path $root "apps\learner-web\src\journey"

$screenPath = Join-Path $journeyRoot "LearnerJourneyScreen.tsx"
$progressPath = Join-Path $journeyRoot "learnerProgress.ts"
$progressTestPath = Join-Path $journeyRoot "learnerProgress.test.ts"
$hookPath = Join-Path $journeyRoot "useLearnerProgress.ts"
$indexPath = Join-Path $journeyRoot "index.ts"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008g-$runId.log"

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

    Copy-Item `
        $Path `
        (Join-Path $backups "$runId-$safe") `
        -Force
}

function InvokeNative([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

    $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $stdout = Join-Path $logs "phase008g-$stamp-out.log"
    $stderr = Join-Path $logs "phase008g-$stamp-err.log"

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
        Add-Content $log $outText -Encoding UTF8
    }

    if ($errText) {
        Write-Host $errText
        Add-Content $log $errText -Encoding UTF8
    }

    if ($process.ExitCode -ne 0) {
        $diag = Join-Path $logs "FAILED-phase008g-$stamp-$($Name.Replace(' ','-')).log"

        WriteText `
            $diag `
            "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$outText`n`nSTDERR:`n$errText"

        throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
    }

    Remove-Item $stdout,$stderr -Force -ErrorAction SilentlyContinue
    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Add-Content `
        $log `
        "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
        -Encoding UTF8

    Write-Host ""
    Write-Host "PHASE 008G: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    Write-Host "No manual intervention should be attempted until this log is reviewed." -ForegroundColor Yellow

    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008G" -ForegroundColor Cyan
Write-Host "Real Learner Progress Integration" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# PRE-FLIGHT CONTRACT CHECKS
# ------------------------------------------------------------------

foreach ($required in @(
    $screenPath,
    $indexPath
)) {
    if (-not (Test-Path $required)) {
        throw "Required file missing: $required"
    }
}

$screenSource = Get-Content $screenPath -Raw

foreach ($requiredToken in @(
    "progressPercent={0}",
    "<LearnerActivityBridge",
    "onClose={",
    "closeActivity"
)) {
    if ($screenSource -notmatch [Regex]::Escape($requiredToken)) {
        throw "LearnerJourneyScreen contract drifted. Missing token: $requiredToken"
    }
}

Write-Host "PASS: LearnerJourneyScreen contract verified" -ForegroundColor Green

# ------------------------------------------------------------------
# BACKUPS
# ------------------------------------------------------------------

Backup $screenPath
Backup $indexPath
Backup $progressPath
Backup $progressTestPath
Backup $hookPath

# ------------------------------------------------------------------
# PURE PROGRESS MODEL
#
# Current offline contract provides:
#   completedSessionCount
#   lastCompletedActivityId
#   updatedAt
#
# Phase 008G deliberately does NOT mutate that persistence schema.
# Progress is bounded against the currently eligible playable activity count.
# ------------------------------------------------------------------

WriteText $progressPath @'
export interface LearnerProgressInput {
  completedSessionCount:
    number;

  playableActivityCount:
    number;
}

export function calculateLearnerProgressPercent({
  completedSessionCount,
  playableActivityCount
}: LearnerProgressInput):
  number {
  if (
    !Number.isFinite(
      completedSessionCount
    ) ||
    !Number.isFinite(
      playableActivityCount
    ) ||
    playableActivityCount <=
      0
  ) {
    return 0;
  }

  const safeCompleted =
    Math.max(
      0,
      Math.floor(
        completedSessionCount
      )
    );

  const safePlayable =
    Math.max(
      1,
      Math.floor(
        playableActivityCount
      )
    );

  return Math.min(
    100,
    Math.round(
      (
        safeCompleted /
        safePlayable
      ) *
      100
    )
  );
}
'@

WriteText $progressTestPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  calculateLearnerProgressPercent
} from "./learnerProgress";

describe(
  "calculateLearnerProgressPercent",
  () => {
    it(
      "returns zero before any completion",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedSessionCount:
              0,

            playableActivityCount:
              2
          })
        ).toBe(0);
      }
    );

    it(
      "calculates progress against the current playable set",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedSessionCount:
              1,

            playableActivityCount:
              2
          })
        ).toBe(50);
      }
    );

    it(
      "clamps progress at one hundred percent",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedSessionCount:
              9,

            playableActivityCount:
              2
          })
        ).toBe(100);
      }
    );

    it(
      "returns zero when no playable activities exist",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedSessionCount:
              3,

            playableActivityCount:
              0
          })
        ).toBe(0);
      }
    );

    it(
      "does not permit negative progress",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedSessionCount:
              -4,

            playableActivityCount:
              2
          })
        ).toBe(0);
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# RUNTIME HOOK
# ------------------------------------------------------------------

WriteText $hookPath @'
import {
  useCallback,
  useEffect,
  useState
} from "react";

import {
  getPlayableActivitiesForAgeBand
} from "@akal-budi/content-library";

import {
  getCachedLearnerRuntimeProfile,
  getLearnerJourneyState
} from "@akal-budi/offline";

import {
  calculateLearnerProgressPercent
} from "./learnerProgress";

export function useLearnerProgress() {
  const [
    progressPercent,
    setProgressPercent
  ] =
    useState(0);

  const refreshProgress =
    useCallback(
      async () => {
        const [
          journey,
          profile
        ] =
          await Promise.all([
            getLearnerJourneyState(),
            getCachedLearnerRuntimeProfile()
          ]);

        if (!profile) {
          setProgressPercent(
            0
          );

          return;
        }

        const playable =
          getPlayableActivitiesForAgeBand(
            profile.ageBand
          );

        setProgressPercent(
          calculateLearnerProgressPercent({
            completedSessionCount:
              journey.completedSessionCount,

            playableActivityCount:
              playable.length
          })
        );
      },
      []
    );

  useEffect(
    () => {
      void refreshProgress();
    },
    [
      refreshProgress
    ]
  );

  return {
    progressPercent,
    refreshProgress
  };
}
'@

# ------------------------------------------------------------------
# STRUCTURAL SCREEN PATCH
# ------------------------------------------------------------------

$tempPatch = Join-Path $env:TEMP "hibeya-phase008g-screen.cjs"

WriteText $tempPatch @'
const fs = require("fs");

const file = process.argv[2];
let source = fs.readFileSync(file,"utf8").replace(/\r\n/g,"\n");

if (
  source.includes(
    'from "./useLearnerProgress"'
  ) &&
  source.includes(
    "progressPercent={\n        progressPercent\n      }"
  ) &&
  source.includes(
    "onComplete={\n                  () =>\n                    void refreshProgress()"
  )
) {
  console.log(
    "PASS: LearnerJourneyScreen already contains Phase 008G integration"
  );

  process.exit(0);
}

const hookImport =
`import {
  useLearnerProgress
} from "./useLearnerProgress";

`;

const journeyImport =
`import {
  useLearnerJourney
} from "./useLearnerJourney";

`;

if (!source.includes(journeyImport)) {
  throw new Error(
    "Could not locate useLearnerJourney import boundary."
  );
}

source =
  source.replace(
    journeyImport,
    journeyImport +
      hookImport
  );

const journeyHook =
`  } =
    useLearnerJourney();

`;

const progressHook =
`  const {
    progressPercent,
    refreshProgress
  } =
    useLearnerProgress();

`;

if (!source.includes(journeyHook)) {
  throw new Error(
    "Could not locate useLearnerJourney hook boundary."
  );
}

source =
  source.replace(
    journeyHook,
    journeyHook +
      progressHook
  );

const oldProgress =
`    <LearnerRuntimeShell
      progressPercent={0}
    >`;

const newProgress =
`    <LearnerRuntimeShell
      progressPercent={
        progressPercent
      }
    >`;

if (!source.includes(oldProgress)) {
  throw new Error(
    "Could not locate hard-coded progressPercent={0}."
  );
}

source =
  source.replace(
    oldProgress,
    newProgress
  );

const oldBridge =
`                onClose={
                  closeActivity
                }
              />`;

const newBridge =
`                onClose={
                  closeActivity
                }
                onComplete={
                  () =>
                    void refreshProgress()
                }
              />`;

if (!source.includes(oldBridge)) {
  throw new Error(
    "Could not locate LearnerActivityBridge completion boundary."
  );
}

source =
  source.replace(
    oldBridge,
    newBridge
  );

fs.writeFileSync(
  file,
  source,
  "utf8"
);

console.log(
  "PASS: LearnerJourneyScreen wired to real progress state"
);
'@

& node $tempPatch $screenPath

if ($LASTEXITCODE -ne 0) {
    throw "LearnerJourneyScreen structural patch failed."
}

Remove-Item $tempPatch -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------------
# BARREL EXPORTS — append only if absent.
# ------------------------------------------------------------------

$indexSource = Get-Content $indexPath -Raw

if ($indexSource -notmatch 'from "\./learnerProgress"') {
    $indexSource =
        $indexSource.TrimEnd() +
        @'

export {
  calculateLearnerProgressPercent,
  type LearnerProgressInput
} from "./learnerProgress";

export {
  useLearnerProgress
} from "./useLearnerProgress";
'@

    WriteText $indexPath $indexSource
}

# ------------------------------------------------------------------
# POSTCONDITIONS
# ------------------------------------------------------------------

$screenVerify = Get-Content $screenPath -Raw

foreach ($requiredToken in @(
    'from "./useLearnerProgress"',
    "refreshProgress",
    "progressPercent={",
    "onComplete={"
)) {
    if ($screenVerify -notmatch [Regex]::Escape($requiredToken)) {
        throw "Phase 008G postcondition failed. Missing: $requiredToken"
    }
}

if ($screenVerify -match 'progressPercent=\{0\}') {
    throw "Hard-coded zero progress still exists after Phase 008G patch."
}

Write-Host "PASS: Phase 008G source postconditions verified" -ForegroundColor Green

# ------------------------------------------------------------------
# TARGETED VALIDATION FIRST
# ------------------------------------------------------------------

InvokeNative `
    "Learner progress unit tests" `
    "pnpm --filter learner-web exec vitest run src/journey/learnerProgress.test.ts"

InvokeNative `
    "Learner web typecheck" `
    "pnpm --filter learner-web typecheck"

InvokeNative `
    "Learner web tests" `
    "pnpm --filter learner-web test"

# ------------------------------------------------------------------
# FULL REGRESSION
# ------------------------------------------------------------------

InvokeNative `
    "Storybook build" `
    "pnpm storybook:build"

InvokeNative `
    "Learner journey regression" `
    "pnpm qa:journey"

InvokeNative `
    "Repository typecheck" `
    "pnpm typecheck"

InvokeNative `
    "All tests" `
    "pnpm test"

InvokeNative `
    "Production build" `
    "pnpm build"

InvokeNative `
    "Accessibility regression" `
    "pnpm qa:a11y"

InvokeNative `
    "Visual regression" `
    "pnpm qa:visual"

InvokeNative `
    "Content compiler check" `
    "pnpm content:check"

InvokeNative `
    "Curriculum validation" `
    "pnpm curriculum:validate"

InvokeNative `
    "Git whitespace check" `
    "git diff --check"

if ($Commit) {
    InvokeNative `
        "Stage Phase 008G" `
        "git add apps/learner-web/src/journey"

    InvokeNative `
        "Commit Phase 008G" `
        'git commit -m "feat: show persisted learner journey progress"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008G: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Progress now loads from persisted offline journey state and refreshes after completion." -ForegroundColor Cyan
Write-Host "The existing offline persistence schema was not modified." -ForegroundColor Cyan
