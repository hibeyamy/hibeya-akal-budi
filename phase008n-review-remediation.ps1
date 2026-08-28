Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008n-review-remediation-$stamp.log"

$servicePath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.ts"
$testPath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.test.ts"
$playerPath = Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"

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
    Copy-Item $Path (Join-Path $backups "$stamp-$safe") -Force
}

function Log([string]$Text = "") {
    Add-Content -Path $log -Value $Text -Encoding UTF8
}

function Invoke-NativeStep([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Write-Host $Command

    Log ""
    Log "==> $Name"
    Log $Command

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & "$env:ComSpec" /d /c $Command 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }

    foreach ($line in $output) {
        $text =
            if ($line -is [System.Management.Automation.ErrorRecord]) {
                $line.Exception.Message
            }
            else {
                [string]$line
            }

        Write-Host $text
        Log $text
    }

    Log "EXIT CODE: $exitCode"

    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode"
    }

    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Log ""
    Log "PHASE 008N: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008N: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    Write-Host "Do not manually edit source until the log has been reviewed." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008N" -ForegroundColor Cyan
Write-Host "Deterministic Mastery Review + Remediation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "HIBEYA AKAL BUDI - PHASE 008N"
Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

# ------------------------------------------------------------------
# 1. Verify exact Phase 008M contracts before writing.
# ------------------------------------------------------------------

foreach ($required in @(
    $servicePath,
    $testPath,
    $playerPath
)) {
    if (-not (Test-Path $required)) {
        throw "Required Phase 008N dependency missing: $required"
    }
}

$service = Get-Content $servicePath -Raw
$player = Get-Content $playerPath -Raw

foreach ($token in @(
    "export interface LearnerSkillProgress",
    "function getActivityNeed",
    "const uncompleted =",
    "skillProgress.length ===",
    "getSequencePosition("
)) {
    if ($service -notmatch [Regex]::Escape($token)) {
        throw "Phase 008M resolver contract drifted. Missing token: $token"
    }
}

foreach ($token in @(
    "getLearnerMasteredSkillIds",
    "recordSessionSkillMastery",
    "journey.completedActivityIds",
    "masteredSkillIds"
)) {
    if ($player -notmatch [Regex]::Escape($token)) {
        throw "ActivityPlayer mastery contract drifted. Missing token: $token"
    }
}

if ($service -match "selectRemediationActivity") {
    throw "Phase 008N remediation implementation already appears installed."
}

Write-Host "PASS: Phase 008M adaptive progression contract verified" -ForegroundColor Green
Write-Host "PASS: ActivityPlayer legacy mastery-only selection path verified" -ForegroundColor Green

Backup $servicePath
Backup $testPath
Backup $playerPath

# ------------------------------------------------------------------
# 2. Replace next-activity resolver with:
#    - unfinished progression first
#    - mastery-aware unfinished ranking
#    - after all eligible content is complete: remediation by need
#    - if no remediation need: existing cyclic fallback
# ------------------------------------------------------------------

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


export function getActivityLearningNeed(
  activity:
    ResolvedPlayableActivity,
  skillProgress:
    readonly LearnerSkillProgress[]
): number {
  if (
    skillProgress.length ===
      0
  ) {
    return 0;
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


function rankByLearningNeed(
  candidates:
    readonly ResolvedPlayableActivity[],
  catalogue:
    readonly ResolvedPlayableActivity[],
  skillProgress:
    readonly LearnerSkillProgress[]
):
  ResolvedPlayableActivity[] {
  return [...candidates]
    .sort(
      (
        left,
        right
      ) => {
        const needDifference =
          getActivityLearningNeed(
            right,
            skillProgress
          ) -
          getActivityLearningNeed(
            left,
            skillProgress
          );

        if (
          Math.abs(
            needDifference
          ) >
            0.000001
        ) {
          return needDifference;
        }

        const sequenceDifference =
          getSequencePosition(
            catalogue,
            left
          ) -
          getSequencePosition(
            catalogue,
            right
          );

        if (
          sequenceDifference !==
            0
        ) {
          return sequenceDifference;
        }

        return left.id.localeCompare(
          right.id
        );
      }
    );
}


export function selectRemediationActivity({
  activities,
  skillProgress
}: {
  activities:
    readonly ResolvedPlayableActivity[];

  skillProgress:
    readonly LearnerSkillProgress[];
}):
  ResolvedPlayableActivity |
  null {
  if (
    activities.length ===
      0 ||
    skillProgress.length ===
      0
  ) {
    return null;
  }

  const ranked =
    rankByLearningNeed(
      activities,
      activities,
      skillProgress
    );

  const candidate =
    ranked[0];

  if (!candidate) {
    return null;
  }

  const need =
    getActivityLearningNeed(
      candidate,
      skillProgress
    );

  return need >
    0
    ? candidate
    : null;
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

    return (
      rankByLearningNeed(
        uncompleted,
        activities,
        skillProgress
      )[0] ??
      null
    );
  }

  const remediation =
    selectRemediationActivity({
      activities,
      skillProgress
    });

  if (
    remediation
  ) {
    return remediation;
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
# 3. Replace focused resolver tests with explicit 008N contract.
# ------------------------------------------------------------------

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
  getActivityLearningNeed,
  resolveNextLearnerActivity,
  selectRemediationActivity
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
        "skill-a"
      );

    const second =
      activity(
        "second",
        20,
        "skill-b"
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
      "prioritises a weaker skill while unfinished content remains",
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
                  "skill-a",
                masteryScore:
                  0.9,
                observationCount:
                  3,
                level:
                  "mastered"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.2,
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
      "never replaces unfinished progression with a completed remediation activity",
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
                  "skill-a",
                masteryScore:
                  0.05,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
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
      "selects completed content targeting the weakest skill only after normal progression is exhausted",
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
              "second",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.15,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.65,
                observationCount:
                  2,
                level:
                  "developing"
              }
            ]
          })?.id
        ).toBe(
          "first"
        );
      }
    );


    it(
      "falls back to cyclic catalogue order when all observed skills are mastered",
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
              "first",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  1,
                observationCount:
                  3,
                level:
                  "mastered"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  1,
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
      "uses catalogue sequence as deterministic remediation tie-break",
      () => {
        expect(
          selectRemediationActivity({
            activities,
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.4,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.4,
                observationCount:
                  2,
                level:
                  "exploring"
              }
            ]
          })?.id
        ).toBe(
          "first"
        );
      }
    );


    it(
      "returns zero learning need for a mastered primary skill",
      () => {
        expect(
          getActivityLearningNeed(
            first,
            [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  1,
                observationCount:
                  3,
                level:
                  "mastered"
              }
            ]
          )
        ).toBe(
          0
        );
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# 4. Normalise ActivityPlayer to the same detailed mastery contract used
#    by Home/useNextLearnerActivity. This avoids two selection behaviours.
# ------------------------------------------------------------------

$player = Get-Content $playerPath -Raw

$oldImport = @'
import {
  getLearnerMasteredSkillIds,
  recordSessionSkillMastery
} from "../../services/skillMasteryService";
'@

$newImport = @'
import {
  getLearnerSkillProgress,
  recordSessionSkillMastery
} from "../../services/skillMasteryService";
'@

if (-not $player.Contains($oldImport)) {
    throw "ActivityPlayer mastery import anchor not found."
}

$player = $player.Replace(
    $oldImport,
    $newImport
)

$oldLoad = @'
    const [
      journey,
      masteredSkillIds
    ] =
      await Promise.all([
        getLearnerJourneyState(),
        getLearnerMasteredSkillIds()
      ]);
'@

$newLoad = @'
    const [
      journey,
      skillProgress
    ] =
      await Promise.all([
        getLearnerJourneyState(),
        getLearnerSkillProgress()
      ]);

    const masteredSkillIds =
      skillProgress
        .filter(
          skill =>
            skill.level ===
              "mastered"
        )
        .map(
          skill =>
            skill.skillId
        );
'@

if (-not $player.Contains($oldLoad)) {
    throw "ActivityPlayer mastery loading anchor not found."
}

$player = $player.Replace(
    $oldLoad,
    $newLoad
)

$oldSelectionTail = @'
        completedActivityIds:
          journey.completedActivityIds,

        masteredSkillIds
      });
'@

$newSelectionTail = @'
        completedActivityIds:
          journey.completedActivityIds,

        masteredSkillIds,

        skillProgress
      });
'@

if (-not $player.Contains($oldSelectionTail)) {
    throw "ActivityPlayer selection input anchor not found."
}

$player = $player.Replace(
    $oldSelectionTail,
    $newSelectionTail
)

WriteText $playerPath $player

$playerCheck = Get-Content $playerPath -Raw

foreach ($token in @(
    "getLearnerSkillProgress",
    "const masteredSkillIds =",
    "skillProgress"
)) {
    if ($playerCheck -notmatch [Regex]::Escape($token)) {
        throw "ActivityPlayer normalisation postcondition failed. Missing token: $token"
    }
}

if ($playerCheck -match "getLearnerMasteredSkillIds") {
    throw "ActivityPlayer still contains the legacy mastery-only read path."
}

Write-Host "PASS: remediation only activates after all eligible unfinished content is complete" -ForegroundColor Green
Write-Host "PASS: weak-skill remediation is deterministic and data-driven" -ForegroundColor Green
Write-Host "PASS: mastered-skill state falls back to the established cyclic catalogue behaviour" -ForegroundColor Green
Write-Host "PASS: ActivityPlayer and Home now use the same detailed mastery-selection contract" -ForegroundColor Green

# ------------------------------------------------------------------
# 5. Focused gates first, then full repository validation.
# ------------------------------------------------------------------

Invoke-NativeStep `
    "Review/remediation resolver tests" `
    "pnpm --filter learner-web exec vitest run src/journey/nextLearnerActivity.service.test.ts"

Invoke-NativeStep `
    "Learner selector tests" `
    "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"

Invoke-NativeStep `
    "Learner web typecheck" `
    "pnpm --filter learner-web typecheck"

Invoke-NativeStep `
    "Learner web tests" `
    "pnpm --filter learner-web test"

Invoke-NativeStep `
    "Mastery validation" `
    "pnpm mastery:validate"

Invoke-NativeStep `
    "Content sequencing validation" `
    "pnpm content:sequence:validate"

Invoke-NativeStep `
    "Content eligibility validation" `
    "pnpm content:eligibility:validate"

Invoke-NativeStep `
    "Curriculum validation" `
    "pnpm curriculum:validate"

Invoke-NativeStep `
    "Repository typecheck" `
    "pnpm typecheck"

Invoke-NativeStep `
    "All tests" `
    "pnpm test"

Invoke-NativeStep `
    "Production build" `
    "pnpm build"

Invoke-NativeStep `
    "Storybook production build" `
    "pnpm storybook:build"

Invoke-NativeStep `
    "Learner journey regression" `
    "pnpm qa:journey"

Invoke-NativeStep `
    "Accessibility regression" `
    "pnpm qa:a11y"

Invoke-NativeStep `
    "Visual regression" `
    "pnpm qa:visual"

Invoke-NativeStep `
    "Content compiler reproducibility" `
    "pnpm content:check"

Invoke-NativeStep `
    "Frozen lockfile verification" `
    "pnpm install --frozen-lockfile"

Invoke-NativeStep `
    "Git whitespace check" `
    "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008N: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Unfinished eligible learning remains the first priority." -ForegroundColor Cyan
Write-Host "After completion, weak non-mastered skills drive deterministic review." -ForegroundColor Cyan
Write-Host "No spaced-repetition schedule or arbitrary timing policy was introduced." -ForegroundColor Cyan
Write-Host "No schema, persistence version, manifest, dependency, or lockfile change was required." -ForegroundColor Cyan
Write-Host "Log: $log" -ForegroundColor White
