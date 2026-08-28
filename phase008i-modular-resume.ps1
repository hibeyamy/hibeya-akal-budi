param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008i-modular-resume-$runId.log"

$screenPath = Join-Path $root "apps\learner-web\src\journey\LearnerJourneyScreen.tsx"
$selectorPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.ts"
$selectorTestPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.test.ts"
$servicePath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.ts"
$serviceTestPath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.test.ts"
$hookPath = Join-Path $root "apps\learner-web\src\journey\useNextLearnerActivity.ts"
$indexPath = Join-Path $root "apps\learner-web\src\journey\index.ts"

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
  $out = Join-Path $logs "phase008i-$stamp-out.log"
  $err = Join-Path $logs "phase008i-$stamp-err.log"

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
    $diag = Join-Path $logs "FAILED-phase008i-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 008I: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  Write-Host "Do not make manual source edits unless explicitly requested after log review." -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008I" -ForegroundColor Cyan
Write-Host "Modular Resume / Next Activity Architecture" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($required in @(
  $screenPath,
  $selectorPath,
  $indexPath
)) {
  if (-not (Test-Path $required)) {
    throw "Required file missing: $required"
  }
}

$screenSource = Get-Content $screenPath -Raw
$selectorSource = Get-Content $selectorPath -Raw

foreach ($token in @(
  'openActivity(',
  '"warna-merah-001"',
  "useLearnerProgress"
)) {
  if ($screenSource -notmatch [Regex]::Escape($token)) {
    throw "LearnerJourneyScreen contract drifted. Missing token: $token"
  }
}

foreach ($token in @(
  "getPlayableActivitiesForAgeBand",
  "lastCompletedActivityId",
  "const ordered",
  "const nextIndex"
)) {
  if ($selectorSource -notmatch [Regex]::Escape($token)) {
    throw "selectLearnerActivity contract drifted. Missing token: $token"
  }
}

Write-Host "PASS: current journey and selector contracts verified" -ForegroundColor Green

foreach ($path in @(
  $screenPath,
  $selectorPath,
  $selectorTestPath,
  $servicePath,
  $serviceTestPath,
  $hookPath,
  $indexPath
)) {
  Backup $path
}

# ------------------------------------------------------------------
# Pure domain service. It consumes catalogue order rather than embedding
# activity IDs or curriculum-specific sorting in the UI/orchestrator.
# ------------------------------------------------------------------

WriteText $servicePath @'
import type {
  ResolvedPlayableActivity
} from "@akal-budi/content-library";

export interface NextLearnerActivityInput {
  activities:
    readonly ResolvedPlayableActivity[];

  completedActivityIds:
    readonly string[];

  lastCompletedActivityId:
    string | null;
}

export function resolveNextLearnerActivity({
  activities,
  completedActivityIds,
  lastCompletedActivityId
}: NextLearnerActivityInput):
  ResolvedPlayableActivity |
  null {
  if (
    activities.length ===
    0
  ) {
    return null;
  }

  const completed =
    new Set(
      completedActivityIds
    );

  const firstUncompleted =
    activities.find(
      activity =>
        !completed.has(
          activity.id
        )
    );

  if (
    firstUncompleted
  ) {
    return firstUncompleted;
  }

  const currentIndex =
    lastCompletedActivityId
      ? activities.findIndex(
          activity =>
            activity.id ===
            lastCompletedActivityId
        )
      : -1;

  if (
    currentIndex <
    0
  ) {
    return (
      activities[0] ??
      null
    );
  }

  const nextIndex =
    (
      currentIndex +
      1
    ) %
    activities.length;

  return (
    activities[nextIndex] ??
    activities[0] ??
    null
  );
}
'@

# ------------------------------------------------------------------
# Compatibility selector: preserve public API but delegate sequencing policy.
# It no longer sorts by Malaysian relevance/difficulty/ID inside learner-web.
# The content catalogue becomes the sequencing authority.
# ------------------------------------------------------------------

WriteText $selectorPath @'
import {
  getPlayableActivitiesForAgeBand,
  type ResolvedPlayableActivity
} from "@akal-budi/content-library";

import type {
  LearnerAgeBand
} from "../../services/deviceActivationService";

import {
  resolveNextLearnerActivity
} from "../../journey/nextLearnerActivity.service";

export interface LearnerActivitySelectionInput {
  ageBand:
    LearnerAgeBand;

  lastCompletedActivityId:
    string | null;

  completedActivityIds?:
    readonly string[];
}

export function selectLearnerActivity({
  ageBand,
  lastCompletedActivityId,
  completedActivityIds = []
}: LearnerActivitySelectionInput):
  ResolvedPlayableActivity |
  null {
  return resolveNextLearnerActivity({
    activities:
      getPlayableActivitiesForAgeBand(
        ageBand
      ),

    completedActivityIds,

    lastCompletedActivityId
  });
}
'@

# ------------------------------------------------------------------
# Hook/service boundary: repository access and learner-profile resolution are
# kept outside the screen. LearnerJourneyScreen receives only "open next".
# ------------------------------------------------------------------

WriteText $hookPath @'
import {
  useCallback
} from "react";

import {
  getCachedLearnerRuntimeProfile,
  getLearnerJourneyState
} from "@akal-budi/offline";

import {
  selectLearnerActivity
} from "../features/play/selectLearnerActivity";

export interface UseNextLearnerActivityInput {
  openActivity:
    (
      activityId: string,
      from:
        "home" |
        "explore"
    ) => void;
}

export function useNextLearnerActivity({
  openActivity
}: UseNextLearnerActivityInput) {
  const openNextActivity =
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
          return;
        }

        const activity =
          selectLearnerActivity({
            ageBand:
              profile.ageBand,

            lastCompletedActivityId:
              journey.lastCompletedActivityId,

            completedActivityIds:
              journey.completedActivityIds
          });

        if (!activity) {
          return;
        }

        openActivity(
          activity.id,
          "home"
        );
      },
      [
        openActivity
      ]
    );

  return {
    openNextActivity
  };
}
'@

WriteText $serviceTestPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import type {
  ResolvedPlayableActivity
} from "@akal-budi/content-library";

import {
  resolveNextLearnerActivity
} from "./nextLearnerActivity.service";

function activity(
  id: string
):
  ResolvedPlayableActivity {
  return {
    id
  } as ResolvedPlayableActivity;
}

describe(
  "resolveNextLearnerActivity",
  () => {
    it(
      "returns null for an empty catalogue",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities:
              [],

            completedActivityIds:
              [],

            lastCompletedActivityId:
              null
          })
        ).toBeNull();
      }
    );

    it(
      "selects the first uncompleted activity in catalogue order",
      () => {
        const selected =
          resolveNextLearnerActivity({
            activities:
              [
                activity("a"),
                activity("b"),
                activity("c")
              ],

            completedActivityIds:
              ["a"],

            lastCompletedActivityId:
              "a"
          });

        expect(
          selected?.id
        ).toBe("b");
      }
    );

    it(
      "does not duplicate completed activities while uncompleted content remains",
      () => {
        const selected =
          resolveNextLearnerActivity({
            activities:
              [
                activity("a"),
                activity("b")
              ],

            completedActivityIds:
              ["a", "a"],

            lastCompletedActivityId:
              "a"
          });

        expect(
          selected?.id
        ).toBe("b");
      }
    );

    it(
      "cycles only after every eligible activity is complete",
      () => {
        const selected =
          resolveNextLearnerActivity({
            activities:
              [
                activity("a"),
                activity("b")
              ],

            completedActivityIds:
              ["a", "b"],

            lastCompletedActivityId:
              "b"
          });

        expect(
          selected?.id
        ).toBe("a");
      }
    );

    it(
      "uses the first catalogue item when the previous activity is no longer eligible",
      () => {
        const selected =
          resolveNextLearnerActivity({
            activities:
              [
                activity("a"),
                activity("b")
              ],

            completedActivityIds:
              ["a", "b"],

            lastCompletedActivityId:
              "legacy"
          });

        expect(
          selected?.id
        ).toBe("a");
      }
    );
  }
);
'@

# Preserve selector-level coverage using the actual catalogue without embedding
# knowledge of specific activity IDs.
WriteText $selectorTestPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  getPlayableActivitiesForAgeBand
} from "@akal-budi/content-library";

import {
  selectLearnerActivity
} from "./selectLearnerActivity";

describe(
  "selectLearnerActivity",
  () => {
    it(
      "follows the playable catalogue order",
      () => {
        const catalogue =
          getPlayableActivitiesForAgeBand(
            "4-6"
          );

        const selected =
          selectLearnerActivity({
            ageBand:
              "4-6",

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
        const catalogue =
          getPlayableActivitiesForAgeBand(
            "4-6"
          );

        const first =
          catalogue[0];

        if (!first) {
          expect(
            selectLearnerActivity({
              ageBand:
                "4-6",

              lastCompletedActivityId:
                null,

              completedActivityIds:
                []
            })
          ).toBeNull();

          return;
        }

        const selected =
          selectLearnerActivity({
            ageBand:
              "4-6",

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
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# Patch screen structurally: it should know only openNextActivity.
# ------------------------------------------------------------------

$editor = Join-Path $env:TEMP "hibeya-phase008i-screen-$runId.cjs"

WriteText $editor @'
const fs = require("fs");

const file = process.argv[2];
let source = fs.readFileSync(file,"utf8").replace(/\r\n/g,"\n");

function requireCondition(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const progressImport =
`import {
  useLearnerProgress
} from "./useLearnerProgress";
`;

const nextImport =
`import {
  useNextLearnerActivity
} from "./useNextLearnerActivity";
`;

if (!source.includes(nextImport)) {
  requireCondition(
    source.includes(progressImport),
    "Could not locate useLearnerProgress import boundary."
  );

  source =
    source.replace(
      progressImport,
      progressImport +
      "\n" +
      nextImport
    );
}

const journeyHookEnd =
`  } =
    useLearnerJourney();
`;

const nextHook =
`
  const {
    openNextActivity
  } =
    useNextLearnerActivity({
      openActivity
    });
`;

if (!source.includes("openNextActivity")) {
  requireCondition(
    source.includes(journeyHookEnd),
    "Could not locate useLearnerJourney hook boundary."
  );

  source =
    source.replace(
      journeyHookEnd,
      journeyHookEnd +
      nextHook
    );
}

const oldContinue =
`                onContinue={
                  () =>
                    openActivity(
                      "warna-merah-001",
                      "home"
                    )
                }`;

const newContinue =
`                onContinue={
                  () =>
                    void openNextActivity()
                }`;

requireCondition(
  source.includes(oldContinue),
  "Could not locate verified hard-coded home continue block."
);

source =
  source.replace(
    oldContinue,
    newContinue
  );

requireCondition(
  !source.includes('"warna-merah-001"'),
  "Activity-specific hard-coded ID remains in LearnerJourneyScreen."
);

requireCondition(
  source.includes("openNextActivity"),
  "Modular next-activity boundary was not installed."
);

fs.writeFileSync(file,source,"utf8");
console.log("PASS: LearnerJourneyScreen reduced to modular next-activity orchestration");
'@

& node $editor $screenPath

if ($LASTEXITCODE -ne 0) {
  throw "LearnerJourneyScreen modular transformation failed."
}

Remove-Item $editor -Force -ErrorAction SilentlyContinue

# Barrel exports for reusable architecture.
$indexSource = Get-Content $indexPath -Raw

if ($indexSource -notmatch 'from "\./nextLearnerActivity\.service"') {
  $indexSource =
    $indexSource.TrimEnd() +
@'

export {
  resolveNextLearnerActivity,
  type NextLearnerActivityInput
} from "./nextLearnerActivity.service";

export {
  useNextLearnerActivity,
  type UseNextLearnerActivityInput
} from "./useNextLearnerActivity";
'@

  WriteText $indexPath $indexSource
}

# ------------------------------------------------------------------
# Postconditions
# ------------------------------------------------------------------

$screenVerify = Get-Content $screenPath -Raw
$selectorVerify = Get-Content $selectorPath -Raw

if ($screenVerify -match 'warna-(merah|bunga-raya)-001') {
  throw "LearnerJourneyScreen still contains activity-specific content IDs."
}

if ($screenVerify -notmatch 'openNextActivity') {
  throw "LearnerJourneyScreen does not use modular next-activity API."
}

foreach ($forbidden in @(
  "malaysiaElements",
  ".difficulty",
  "localeCompare"
)) {
  if ($selectorVerify -match [Regex]::Escape($forbidden)) {
    throw "App selector still embeds content sequencing policy: $forbidden"
  }
}

Write-Host "PASS: no activity ID hard-coding remains in LearnerJourneyScreen" -ForegroundColor Green
Write-Host "PASS: learner-web selector no longer owns curriculum ordering rules" -ForegroundColor Green
Write-Host "PASS: next-activity selection isolated behind reusable service/hook boundary" -ForegroundColor Green

# ------------------------------------------------------------------
# Focused validation first.
# ------------------------------------------------------------------

Run `
  "Next activity service tests" `
  "pnpm --filter learner-web exec vitest run src/journey/nextLearnerActivity.service.test.ts"

Run `
  "Selector tests" `
  "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"

Run `
  "Learner web typecheck" `
  "pnpm --filter learner-web typecheck"

Run `
  "Learner web tests" `
  "pnpm --filter learner-web test"

# Full quality gates.
Run `
  "Storybook production build" `
  "pnpm storybook:build"

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
  "Production build" `
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
    "Stage Phase 008I" `
    "git add apps/learner-web/src/journey apps/learner-web/src/features/play/selectLearnerActivity.ts apps/learner-web/src/features/play/selectLearnerActivity.test.ts"

  Run `
    "Commit Phase 008I" `
    'git commit -m "refactor: modularise learner next activity selection"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008I: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "LearnerJourneyScreen is now content-agnostic." -ForegroundColor Cyan
Write-Host "The content catalogue is the current sequencing authority." -ForegroundColor Cyan
Write-Host "No manual intervention is required." -ForegroundColor Cyan
