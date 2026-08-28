Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008m-adaptive-progression-$stamp.txt"

function Log([string]$Text = "") {
    $Text | Tee-Object -FilePath $log -Append
}

function Run([string]$Label, [string]$Command) {
    Log ""
    Log "---- $Label ----"
    Log $Command
    cmd.exe /d /s /c $Command 2>&1 | Tee-Object -FilePath $log -Append
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

function WriteText([string]$Path, [string]$Content) {
    $parent = Split-Path $Path -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [System.IO.File]::WriteAllText(
        $Path,
        ($Content -replace "`r`n","`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
}

trap {
    Log ""
    Log "PHASE 008M: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Write-Host ""
    Write-Host "PHASE 008M: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008M" -ForegroundColor Cyan
Write-Host "Mastery-Aware Adaptive Progression" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "HIBEYA AKAL BUDI - PHASE 008M"
Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

$servicePath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.ts"
$testPath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.test.ts"

if (-not (Test-Path $servicePath)) {
    throw "Missing next learner activity service."
}

# The preflight showed mastery already gates prerequisite eligibility.
# Phase 008M deliberately keeps that boundary intact and adds adaptive
# ranking only after eligibility has been resolved.
WriteText $servicePath @'
import type {
  ResolvedPlayableActivity
} from "@akal-budi/content-library";


export interface LearnerSkillProgress {
  skillId: string;

  masteryScore: number;

  observationCount: number;

  level:
    "unobserved" |
    "exploring" |
    "developing" |
    "mastered";
}


export interface NextLearnerActivityInput {
  activities:
    readonly ResolvedPlayableActivity[];

  completedActivityIds:
    readonly string[];

  lastCompletedActivityId:
    string | null;

  skillProgress?:
    readonly LearnerSkillProgress[];
}


function clamp01(
  value: number
): number {
  return Math.max(
    0,
    Math.min(
      1,
      value
    )
  );
}


function getSkillNeed(
  skillId: string,
  progress:
    ReadonlyMap<
      string,
      LearnerSkillProgress
    >
): number {
  const record =
    progress.get(
      skillId
    );

  if (!record) {
    return 0.5;
  }

  if (
    record.level ===
      "mastered"
  ) {
    return 0;
  }

  return (
    1 -
    clamp01(
      record.masteryScore
    )
  );
}


function getActivityNeed(
  activity:
    ResolvedPlayableActivity,
  progress:
    ReadonlyMap<
      string,
      LearnerSkillProgress
    >
): number {
  const mappings =
    activity.skillMappings ??
    [];

  if (
    mappings.length ===
      0
  ) {
    return 0;
  }

  let weightedNeed =
    0;

  let totalWeight =
    0;

  for (
    const mapping
    of mappings
  ) {
    const weight =
      Math.max(
        0,
        mapping.weight
      );

    if (
      weight ===
        0
    ) {
      continue;
    }

    const roleMultiplier =
      mapping.role ===
        "primary"
        ? 1
        : 0.5;

    const effectiveWeight =
      weight *
      roleMultiplier;

    weightedNeed +=
      getSkillNeed(
        mapping.skillId,
        progress
      ) *
      effectiveWeight;

    totalWeight +=
      effectiveWeight;
  }

  return totalWeight >
    0
    ? weightedNeed /
        totalWeight
    : 0;
}


function getSequencePosition(
  activities:
    readonly ResolvedPlayableActivity[],
  activity:
    ResolvedPlayableActivity
): number {
  const index =
    activities.findIndex(
      candidate =>
        candidate.id ===
          activity.id
    );

  return index >=
    0
    ? index
    : Number.MAX_SAFE_INTEGER;
}


export function resolveNextLearnerActivity({
  activities,
  completedActivityIds,
  lastCompletedActivityId,
  skillProgress = []
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

  const uncompleted =
    activities.filter(
      activity =>
        !completed.has(
          activity.id
        )
    );

  if (
    uncompleted.length >
      0
  ) {
    if (
      skillProgress.length ===
        0
    ) {
      return (
        uncompleted[0] ??
        null
      );
    }

    const progress =
      new Map(
        skillProgress.map(
          record => [
            record.skillId,
            record
          ] as const
        )
      );

    return (
      [...uncompleted]
        .sort(
          (
            left,
            right
          ) => {
            const needDifference =
              getActivityNeed(
                right,
                progress
              ) -
              getActivityNeed(
                left,
                progress
              );

            if (
              Math.abs(
                needDifference
              ) >
                0.000001
            ) {
              return needDifference;
            }

            return (
              getSequencePosition(
                activities,
                left
              ) -
              getSequencePosition(
                activities,
                right
              )
            );
          }
        )[0] ??
      null
    );
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

WriteText $testPath @'
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
  id: string,
  sequence: number,
  skillId: string
): ResolvedPlayableActivity {
  return {
    id,
    blueprintId:
      "test-blueprint",
    version:
      1,
    enabled:
      true,
    sequence,
    skillIds:
      [skillId],
    skillMappings: [
      {
        skillId,
        role:
          "primary",
        weight:
          1
      }
    ],
    primarySkillIds:
      [skillId],
    requiredPrerequisiteSkillIds:
      [],
    ageBands:
      ["3-4"],
    titleMs:
      id,
    titleEn:
      id,
    implementationKey:
      "test",
    blueprint:
      {} as ResolvedPlayableActivity["blueprint"]
  };
}


describe(
  "resolveNextLearnerActivity",
  () => {
    const first =
      activity(
        "first",
        10,
        "colour-recognition"
      );

    const second =
      activity(
        "second",
        20,
        "visual-discrimination"
      );

    const activities =
      [
        first,
        second
      ];


    it(
      "preserves catalogue order when mastery detail is unavailable",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities,
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null
          })?.id
        ).toBe(
          "first"
        );
      }
    );


    it(
      "prioritises an uncompleted activity targeting the weaker observed skill",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities,
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress: [
              {
                skillId:
                  "colour-recognition",
                masteryScore:
                  0.9,
                observationCount:
                  3,
                level:
                  "mastered"
              },
              {
                skillId:
                  "visual-discrimination",
                masteryScore:
                  0.25,
                observationCount:
                  2,
                level:
                  "exploring"
              }
            ]
          })?.id
        ).toBe(
          "second"
        );
      }
    );


    it(
      "does not replace uncompleted progression with completed remediation",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities,
            completedActivityIds:
              ["first"],
            lastCompletedActivityId:
              "first",
            skillProgress: [
              {
                skillId:
                  "colour-recognition",
                masteryScore:
                  0.1,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "visual-discrimination",
                masteryScore:
                  0.9,
                observationCount:
                  3,
                level:
                  "mastered"
              }
            ]
          })?.id
        ).toBe(
          "second"
        );
      }
    );


    it(
      "cycles catalogue order after every eligible activity is completed",
      () => {
        expect(
          resolveNextLearnerActivity({
            activities,
            completedActivityIds:
              [
                "first",
                "second"
              ],
            lastCompletedActivityId:
              "first"
          })?.id
        ).toBe(
          "second"
        );
      }
    );
  }
);
'@

# Patch mastery service with a read API for detailed progression.
$masteryServicePath = Join-Path $root "apps\learner-web\src\services\skillMasteryService.ts"
$masterySource = Get-Content $masteryServicePath -Raw

if ($masterySource -notmatch "getLearnerSkillProgress") {
    $anchor = "export async function getLearnerMasteredSkillIds():"
    if (-not $masterySource.Contains($anchor)) {
        throw "Mastery service contract drifted."
    }

    $addition = @'
export async function getLearnerSkillProgress():
  Promise<
    Array<{
      skillId: string;
      masteryScore: number;
      observationCount: number;
      level:
        "unobserved" |
        "exploring" |
        "developing" |
        "mastered";
    }>
  > {
  const stored =
    await getLearnerSkillMasteryState();

  const state =
    toDomainState(
      stored
    );

  return Object.values(
    state.skills
  )
    .map(
      record => ({
        skillId:
          record.skillId,
        masteryScore:
          record.masteryScore,
        observationCount:
          record.observationCount,
        level:
          record.level
      })
    )
    .sort(
      (
        left,
        right
      ) =>
        left.skillId.localeCompare(
          right.skillId
        )
    );
}


'@

    $masterySource = $masterySource.Replace($anchor, $addition + $anchor)
    WriteText $masteryServicePath $masterySource
}

# Extend selector input without moving prerequisite policy out of content-library.
$selectorPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.ts"
$selector = Get-Content $selectorPath -Raw

if ($selector -notmatch "skillProgress") {
    $selector = $selector.Replace(
@'
  masteredSkillIds?:
    readonly string[];
'@,
@'
  masteredSkillIds?:
    readonly string[];

  skillProgress?:
    readonly import("../../journey/nextLearnerActivity.service").LearnerSkillProgress[];
'@
    )

    $selector = $selector.Replace(
@'
  completedActivityIds = [],
  masteredSkillIds = []
}: LearnerActivitySelectionInput):
'@,
@'
  completedActivityIds = [],
  masteredSkillIds = [],
  skillProgress = []
}: LearnerActivitySelectionInput):
'@
    )

    $selector = $selector.Replace(
@'
    completedActivityIds,

    lastCompletedActivityId
'@,
@'
    completedActivityIds,

    lastCompletedActivityId,

    skillProgress
'@
    )

    if ($selector -notmatch "skillProgress") {
        throw "Selector adaptive progression patch failed."
    }

    WriteText $selectorPath $selector
}

# Journey hook loads detailed mastery once and derives mastered IDs from it.
$hookPath = Join-Path $root "apps\learner-web\src\journey\useNextLearnerActivity.ts"
$hook = Get-Content $hookPath -Raw

$hook = $hook.Replace(
@'
  getLearnerMasteredSkillIds
} from "../services/skillMasteryService";
'@,
@'
  getLearnerSkillProgress
} from "../services/skillMasteryService";
'@
)

$hook = $hook.Replace(
@'
          masteredSkillIds
        ] =
          await Promise.all([
            getLearnerJourneyState(),
            getCachedLearnerRuntimeProfile(),
            getLearnerMasteredSkillIds()
          ]);
'@,
@'
          skillProgress
        ] =
          await Promise.all([
            getLearnerJourneyState(),
            getCachedLearnerRuntimeProfile(),
            getLearnerSkillProgress()
          ]);
'@
)

$hook = $hook.Replace(
@'
            masteredSkillIds
          });
'@,
@'
            masteredSkillIds:
              skillProgress
                .filter(
                  skill =>
                    skill.level ===
                      "mastered"
                )
                .map(
                  skill =>
                    skill.skillId
                ),

            skillProgress
          });
'@
)

if (
    $hook -notmatch "getLearnerSkillProgress" -or
    $hook -notmatch "skillProgress"
) {
    throw "Journey hook adaptive progression patch failed."
}

WriteText $hookPath $hook

Write-Host "PASS: adaptive ranking installed behind existing eligibility boundary" -ForegroundColor Green
Write-Host "PASS: catalogue order remains deterministic fallback" -ForegroundColor Green
Write-Host "PASS: completed activities cannot displace unfinished progression" -ForegroundColor Green

Run "Next activity adaptive tests" "pnpm --filter learner-web exec vitest run src/journey/nextLearnerActivity.service.test.ts"
Run "Learner selector tests" "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"
Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Mastery validation" "pnpm mastery:validate"
Run "Content sequencing validation" "pnpm content:sequence:validate"
Run "Content eligibility validation" "pnpm content:eligibility:validate"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Storybook production build" "pnpm storybook:build"
Run "Learner journey regression" "pnpm qa:journey"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression" "pnpm qa:visual"
Run "Content compiler reproducibility" "pnpm content:check"
Run "Frozen lockfile verification" "pnpm install --frozen-lockfile"
Run "Git whitespace check" "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008M: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Eligible unfinished activities are now mastery-aware." -ForegroundColor Cyan
Write-Host "Prerequisite gating remains owned by content-library." -ForegroundColor Cyan
Write-Host "Catalogue sequence remains the deterministic fallback/tie-break." -ForegroundColor Cyan
Write-Host "No schema or persistence version change was required." -ForegroundColor Cyan
Write-Host "Log: $log" -ForegroundColor White
