param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008l-skill-mastery-$runId.log"

$masteryPath = Join-Path $root "packages\learning-insights\src\mastery.ts"
$masteryTestPath = Join-Path $root "packages\learning-insights\src\__tests__\mastery.test.ts"
$learningIndexPath = Join-Path $root "packages\learning-insights\src\index.ts"
$offlineRepoPath = Join-Path $root "packages\offline\src\skillMastery.repository.ts"
$offlineTestPath = Join-Path $root "packages\offline\src\__tests__\skillMastery.repository.test.ts"
$offlineIndexPath = Join-Path $root "packages\offline\src\index.ts"
$eligibilityPath = Join-Path $root "packages\content-library\src\eligibility.ts"
$eligibilityTestPath = Join-Path $root "packages\content-library\src\__tests__\eligibility.test.ts"
$compilerPath = Join-Path $root "tools\content-compiler\compile.mjs"
$selectorPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.ts"
$selectorTestPath = Join-Path $root "apps\learner-web\src\features\play\selectLearnerActivity.test.ts"
$masteryServicePath = Join-Path $root "apps\learner-web\src\services\skillMasteryService.ts"
$playerPath = Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
$nextHookPath = Join-Path $root "apps\learner-web\src\journey\useNextLearnerActivity.ts"
$learnerPackagePath = Join-Path $root "apps\learner-web\package.json"
$rootPackagePath = Join-Path $root "package.json"

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
  $out = Join-Path $logs "phase008l-$stamp-out.log"
  $err = Join-Path $logs "phase008l-$stamp-err.log"

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

  if ($stdout) { Write-Host $stdout; Add-Content $log $stdout -Encoding UTF8 }
  if ($stderr) { Write-Host $stderr; Add-Content $log $stderr -Encoding UTF8 }

  if ($p.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase008l-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 008L: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  Write-Host "Do not make manual source edits unless explicitly requested after log review." -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008L" -ForegroundColor Cyan
Write-Host "Evidence-Based Skill Mastery" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# 1. Verify the exact preflight contracts before modifying anything.
# ------------------------------------------------------------------
foreach ($required in @(
  $learningIndexPath,
  $offlineIndexPath,
  $eligibilityPath,
  $compilerPath,
  $selectorPath,
  $playerPath,
  $nextHookPath,
  $learnerPackagePath,
  $rootPackagePath
)) {
  if (-not (Test-Path $required)) {
    throw "Required Phase 008L dependency missing: $required"
  }
}

$learningIndex = Get-Content $learningIndexPath -Raw
$offlineIndex = Get-Content $offlineIndexPath -Raw
$eligibility = Get-Content $eligibilityPath -Raw
$compiler = Get-Content $compilerPath -Raw
$selector = Get-Content $selectorPath -Raw
$player = Get-Content $playerPath -Raw
$nextHook = Get-Content $nextHookPath -Raw

foreach ($token in @(
  "LearningSessionInput",
  "analyseLearningSessions"
)) {
  if ($learningIndex -notmatch [Regex]::Escape($token)) {
    throw "learning-insights contract drifted. Missing token: $token"
  }
}

foreach ($token in @(
  "recordCompletedJourneyActivity",
  "completeLocalSession",
  "getLearnerJourneyState"
)) {
  if ($offlineIndex -notmatch [Regex]::Escape($token)) {
    throw "offline package contract drifted. Missing token: $token"
  }
}

foreach ($token in @(
  "deriveCompletedSkillIds",
  "getEligibleActivitiesForLearner",
  "completedActivityIds"
)) {
  if ($eligibility -notmatch [Regex]::Escape($token)) {
    throw "008K eligibility contract drifted. Missing token: $token"
  }
}

foreach ($token in @(
  "skillIds:",
  "primarySkillIds:",
  "requiredPrerequisiteSkillIds:",
  "manifest.skillMappings"
)) {
  if ($compiler -notmatch [Regex]::Escape($token)) {
    throw "content compiler 008K contract drifted. Missing token: $token"
  }
}

foreach ($token in @(
  "getEligibleActivitiesForLearner",
  "completedActivityIds"
)) {
  if ($selector -notmatch [Regex]::Escape($token)) {
    throw "learner selector contract drifted. Missing token: $token"
  }
}

foreach ($token in @(
  "const result =",
  "mechanic.complete",
  "completeLocalSession",
  "recordCompletedJourneyActivity",
  "sessionId"
)) {
  if ($player -notmatch [Regex]::Escape($token)) {
    throw "ActivityPlayer evidence contract drifted. Missing token: $token"
  }
}

if ($learningIndex -match "applySkillMasteryEvidence") {
  throw "Phase 008L mastery API already exists. Refusing duplicate migration."
}

Write-Host "PASS: Phase 008L runtime, evidence, eligibility and compiler contracts verified" -ForegroundColor Green

# ------------------------------------------------------------------
# 2. Back up every file that can be changed.
# ------------------------------------------------------------------
foreach ($path in @(
  $masteryPath,
  $masteryTestPath,
  $learningIndexPath,
  $offlineRepoPath,
  $offlineTestPath,
  $offlineIndexPath,
  $eligibilityPath,
  $eligibilityTestPath,
  $compilerPath,
  $selectorPath,
  $selectorTestPath,
  $masteryServicePath,
  $playerPath,
  $nextHookPath,
  $learnerPackagePath,
  $rootPackagePath
)) {
  Backup $path
}

# ------------------------------------------------------------------
# 3. Pure mastery engine in @akal-budi/learning-insights.
# ------------------------------------------------------------------
WriteText $masteryPath @'
export const SKILL_MASTERY_POLICY = {
  minimumObservations:
    2,

  masteryScoreThreshold:
    0.75
} as const;


export type SkillMasteryLevel =
  | "unobserved"
  | "exploring"
  | "developing"
  | "mastered";


export interface SkillEvidenceMapping {
  skillId: string;

  role:
    "primary" |
    "supporting";

  weight: number;
}


export interface SkillMasteryEvidenceInput {
  sessionId: string;

  activityId: string;

  completedAt: number;

  correct: number;

  incorrect: number;

  attempts: number;

  durationSeconds: number;

  skillMappings:
    readonly SkillEvidenceMapping[];
}


export interface SkillMasteryRecord {
  skillId: string;

  successfulAttempts:
    number;

  unsuccessfulAttempts:
    number;

  weightedEvidence:
    number;

  totalWeight:
    number;

  observationCount:
    number;

  masteryScore:
    number;

  level:
    SkillMasteryLevel;

  lastObservedAt:
    number;
}


export interface SkillMasteryState {
  version: 1;

  skills:
    Record<
      string,
      SkillMasteryRecord
    >;

  processedSessionIds:
    string[];

  updatedAt:
    number;
}


export function createEmptySkillMasteryState():
  SkillMasteryState {
  return {
    version:
      1,

    skills:
      {},

    processedSessionIds:
      [],

    updatedAt:
      0
  };
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


export function classifySkillMastery(
  observationCount: number,
  masteryScore: number
): SkillMasteryLevel {
  if (
    observationCount <=
      0
  ) {
    return "unobserved";
  }

  if (
    observationCount >=
      SKILL_MASTERY_POLICY.minimumObservations &&
    masteryScore >=
      SKILL_MASTERY_POLICY.masteryScoreThreshold
  ) {
    return "mastered";
  }

  if (
    masteryScore >=
      0.5
  ) {
    return "developing";
  }

  return "exploring";
}


export function applySkillMasteryEvidence(
  current:
    SkillMasteryState,
  evidence:
    SkillMasteryEvidenceInput
): SkillMasteryState {
  if (
    current.processedSessionIds.includes(
      evidence.sessionId
    )
  ) {
    return current;
  }

  const attempts =
    Math.max(
      0,
      evidence.attempts
    );

  const accuracy =
    attempts > 0
      ? clamp01(
          evidence.correct /
            attempts
        )
      : 0;

  const nextSkills = {
    ...current.skills
  };

  for (
    const mapping
    of evidence.skillMappings
  ) {
    if (
      !mapping.skillId ||
      !Number.isFinite(
        mapping.weight
      ) ||
      mapping.weight <=
        0
    ) {
      continue;
    }

    const previous =
      current.skills[
        mapping.skillId
      ];

    const weightedEvidence =
      (
        previous?.weightedEvidence ??
        0
      ) +
      accuracy *
        mapping.weight;

    const totalWeight =
      (
        previous?.totalWeight ??
        0
      ) +
      mapping.weight;

    const observationCount =
      (
        previous?.observationCount ??
        0
      ) +
      1;

    const masteryScore =
      totalWeight > 0
        ? clamp01(
            weightedEvidence /
              totalWeight
          )
        : 0;

    nextSkills[
      mapping.skillId
    ] = {
      skillId:
        mapping.skillId,

      successfulAttempts:
        (
          previous?.successfulAttempts ??
          0
        ) +
        Math.max(
          0,
          evidence.correct
        ),

      unsuccessfulAttempts:
        (
          previous?.unsuccessfulAttempts ??
          0
        ) +
        Math.max(
          0,
          evidence.incorrect
        ),

      weightedEvidence,

      totalWeight,

      observationCount,

      masteryScore,

      level:
        classifySkillMastery(
          observationCount,
          masteryScore
        ),

      lastObservedAt:
        evidence.completedAt
    };
  }

  return {
    version:
      1,

    skills:
      nextSkills,

    processedSessionIds: [
      ...current.processedSessionIds,
      evidence.sessionId
    ],

    updatedAt:
      evidence.completedAt
  };
}


export function getMasteredSkillIds(
  state:
    SkillMasteryState
): string[] {
  return Object.values(
    state.skills
  )
    .filter(
      record =>
        record.level ===
          "mastered"
    )
    .map(
      record =>
        record.skillId
    )
    .sort();
}
'@

WriteText $masteryTestPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  applySkillMasteryEvidence,
  createEmptySkillMasteryState,
  getMasteredSkillIds
} from "../mastery";


const mappings = [
  {
    skillId:
      "colour-recognition",

    role:
      "primary" as const,

    weight:
      1
  },
  {
    skillId:
      "visual-discrimination",

    role:
      "supporting" as const,

    weight:
      0.5
  }
];


function evidence(
  sessionId: string,
  correct: number,
  incorrect: number
) {
  return {
    sessionId,
    activityId:
      "activity-a",
    completedAt:
      1000,
    correct,
    incorrect,
    attempts:
      correct + incorrect,
    durationSeconds:
      10,
    skillMappings:
      mappings
  };
}


describe(
  "skill mastery",
  () => {
    it(
      "does not master a skill from a single successful observation",
      () => {
        const state =
          applySkillMasteryEvidence(
            createEmptySkillMasteryState(),
            evidence(
              "s1",
              1,
              0
            )
          );

        expect(
          state.skills[
            "colour-recognition"
          ]?.level
        ).toBe(
          "developing"
        );
      }
    );

    it(
      "masters after repeated sufficiently strong evidence",
      () => {
        const first =
          applySkillMasteryEvidence(
            createEmptySkillMasteryState(),
            evidence(
              "s1",
              1,
              0
            )
          );

        const second =
          applySkillMasteryEvidence(
            first,
            evidence(
              "s2",
              1,
              0
            )
          );

        expect(
          getMasteredSkillIds(
            second
          )
        ).toContain(
          "colour-recognition"
        );
      }
    );

    it(
      "does not double count the same session",
      () => {
        const first =
          applySkillMasteryEvidence(
            createEmptySkillMasteryState(),
            evidence(
              "s1",
              1,
              0
            )
          );

        const duplicate =
          applySkillMasteryEvidence(
            first,
            evidence(
              "s1",
              1,
              0
            )
          );

        expect(
          duplicate
        ).toEqual(
          first
        );
      }
    );

    it(
      "keeps mixed evidence below mastery threshold",
      () => {
        const first =
          applySkillMasteryEvidence(
            createEmptySkillMasteryState(),
            evidence(
              "s1",
              1,
              1
            )
          );

        const second =
          applySkillMasteryEvidence(
            first,
            evidence(
              "s2",
              1,
              1
            )
          );

        expect(
          second.skills[
            "colour-recognition"
          ]?.level
        ).not.toBe(
          "mastered"
        );
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# 4. Versioned mastery persistence in the existing settings store.
#    No IndexedDB schema migration.
# ------------------------------------------------------------------
WriteText $offlineRepoPath @'
import {
  getDatabase
} from "./database";


const MASTERY_KEY =
  "learner-skill-mastery-v1";


export type StoredSkillMasteryLevel =
  | "unobserved"
  | "exploring"
  | "developing"
  | "mastered";


export interface StoredSkillMasteryRecord {
  skillId: string;
  successfulAttempts: number;
  unsuccessfulAttempts: number;
  weightedEvidence: number;
  totalWeight: number;
  observationCount: number;
  masteryScore: number;
  level: StoredSkillMasteryLevel;
  lastObservedAt: number;
}


export interface LearnerSkillMasteryState {
  version: 1;

  skills:
    Record<
      string,
      StoredSkillMasteryRecord
    >;

  processedSessionIds:
    string[];

  updatedAt:
    number;
}


const emptyState:
  LearnerSkillMasteryState = {
    version:
      1,
    skills:
      {},
    processedSessionIds:
      [],
    updatedAt:
      0
  };


export async function getLearnerSkillMasteryState():
  Promise<LearnerSkillMasteryState> {
  const db =
    await getDatabase();

  const stored =
    await db.get(
      "settings",
      MASTERY_KEY
    );

  if (
    !stored ||
    !isMasteryState(
      stored.value
    )
  ) {
    return {
      ...emptyState,
      skills:
        {},
      processedSessionIds:
        []
    };
  }

  return normalizeMasteryState(
    stored.value
  );
}


export async function saveLearnerSkillMasteryState(
  state:
    LearnerSkillMasteryState
): Promise<void> {
  const db =
    await getDatabase();

  await db.put(
    "settings",
    {
      key:
        MASTERY_KEY,
      value:
        normalizeMasteryState(
          state
        )
    }
  );
}


export async function clearLearnerSkillMasteryState():
  Promise<void> {
  const db =
    await getDatabase();

  await db.delete(
    "settings",
    MASTERY_KEY
  );
}


function normalizeMasteryState(
  value:
    LearnerSkillMasteryState
): LearnerSkillMasteryState {
  return {
    version:
      1,

    skills:
      value.skills ??
      {},

    processedSessionIds:
      Array.from(
        new Set(
          Array.isArray(
            value.processedSessionIds
          )
            ? value.processedSessionIds.filter(
                id =>
                  typeof id ===
                    "string" &&
                  id.length >
                    0
              )
            : []
        )
      ),

    updatedAt:
      Number.isFinite(
        value.updatedAt
      )
        ? value.updatedAt
        : 0
  };
}


function isMasteryState(
  value: unknown
): value is LearnerSkillMasteryState {
  if (
    typeof value !==
      "object" ||
    value ===
      null
  ) {
    return false;
  }

  const candidate =
    value as Record<
      string,
      unknown
    >;

  return (
    candidate.version ===
      1 &&
    typeof candidate.skills ===
      "object" &&
    candidate.skills !==
      null &&
    Array.isArray(
      candidate.processedSessionIds
    ) &&
    typeof candidate.updatedAt ===
      "number"
  );
}
'@

WriteText $offlineTestPath @'
import "fake-indexeddb/auto";

import {
  beforeEach,
  describe,
  expect,
  it
} from "vitest";

import {
  clearLearnerSkillMasteryState,
  getLearnerSkillMasteryState,
  saveLearnerSkillMasteryState
} from "../skillMastery.repository";


describe(
  "skill mastery repository",
  () => {
    beforeEach(
      async () => {
        await clearLearnerSkillMasteryState();
      }
    );

    it(
      "returns an empty versioned state initially",
      async () => {
        expect(
          await getLearnerSkillMasteryState()
        ).toEqual({
          version:
            1,
          skills:
            {},
          processedSessionIds:
            [],
          updatedAt:
            0
        });
      }
    );

    it(
      "persists and deduplicates processed session ids",
      async () => {
        await saveLearnerSkillMasteryState({
          version:
            1,
          skills:
            {},
          processedSessionIds: [
            "s1",
            "s1"
          ],
          updatedAt:
            123
        });

        expect(
          (
            await getLearnerSkillMasteryState()
          ).processedSessionIds
        ).toEqual([
          "s1"
        ]);
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# 5. Learner orchestration service bridges pure engine + persistence.
# ------------------------------------------------------------------
WriteText $masteryServicePath @'
import {
  applySkillMasteryEvidence,
  createEmptySkillMasteryState,
  getMasteredSkillIds,
  type SkillEvidenceMapping,
  type SkillMasteryState
} from "@akal-budi/learning-insights";

import {
  getLearnerSkillMasteryState,
  saveLearnerSkillMasteryState
} from "@akal-budi/offline";

import type {
  GameSessionResult
} from "@akal-budi/game-runtime";


function toDomainState(
  stored:
    Awaited<
      ReturnType<
        typeof getLearnerSkillMasteryState
      >
    >
): SkillMasteryState {
  return {
    ...createEmptySkillMasteryState(),
    ...stored
  } as SkillMasteryState;
}


export async function getLearnerMasteredSkillIds():
  Promise<string[]> {
  const stored =
    await getLearnerSkillMasteryState();

  return getMasteredSkillIds(
    toDomainState(
      stored
    )
  );
}


export async function recordSessionSkillMastery({
  sessionId,
  result,
  skillMappings
}: {
  sessionId: string;
  result: GameSessionResult;
  skillMappings:
    readonly SkillEvidenceMapping[];
}): Promise<string[]> {
  const stored =
    await getLearnerSkillMasteryState();

  const next =
    applySkillMasteryEvidence(
      toDomainState(
        stored
      ),
      {
        sessionId,
        activityId:
          result.activityId,
        completedAt:
          result.completedAt,
        correct:
          result.correct,
        incorrect:
          result.incorrect,
        attempts:
          result.attempts,
        durationSeconds:
          result.durationSeconds,
        skillMappings
      }
    );

  if (
    next !==
      toDomainState(
        stored
      )
  ) {
    await saveLearnerSkillMasteryState(
      next
    );
  }

  return getMasteredSkillIds(
    next
  );
}
'@

# Fix the identity comparison in the generated service with a stable processed-session guard.
$svc = Get-Content $masteryServicePath -Raw
$svc = $svc.Replace(
'  const next =
    applySkillMasteryEvidence(
      toDomainState(
        stored
      ),',
'  const current =
    toDomainState(
      stored
    );

  const alreadyProcessed =
    current.processedSessionIds.includes(
      sessionId
    );

  const next =
    applySkillMasteryEvidence(
      current,'
)
$svc = $svc.Replace(
'  if (
    next !==
      toDomainState(
        stored
      )
  ) {',
'  if (
    !alreadyProcessed
  ) {'
)
WriteText $masteryServicePath $svc

# ------------------------------------------------------------------
# 6. Content eligibility now consumes mastered skill IDs explicitly.
# ------------------------------------------------------------------
WriteText $eligibilityPath @'
import type {
  AgeBand
} from "@akal-budi/content-architecture";

import {
  getPlayableActivitiesForAgeBand,
  type ResolvedPlayableActivity
} from "./catalogue";


export interface LearnerEligibilityInput {
  ageBand:
    AgeBand;

  masteredSkillIds:
    readonly string[];
}


export function isActivityPrerequisiteEligible(
  activity:
    ResolvedPlayableActivity,
  masteredSkillIds:
    ReadonlySet<string>
): boolean {
  return activity
    .requiredPrerequisiteSkillIds
    .every(
      skillId =>
        masteredSkillIds.has(
          skillId
        )
    );
}


export function getEligibleActivitiesForLearner({
  ageBand,
  masteredSkillIds
}: LearnerEligibilityInput):
  ResolvedPlayableActivity[] {
  const mastered =
    new Set(
      masteredSkillIds
    );

  return getPlayableActivitiesForAgeBand(
    ageBand
  ).filter(
    activity =>
      isActivityPrerequisiteEligible(
        activity,
        mastered
      )
  );
}
'@

WriteText $eligibilityTestPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  isActivityPrerequisiteEligible
} from "../eligibility";

import type {
  ResolvedPlayableActivity
} from "../catalogue";


function activity(
  requiredPrerequisiteSkillIds:
    readonly string[]
): ResolvedPlayableActivity {
  return {
    requiredPrerequisiteSkillIds
  } as ResolvedPlayableActivity;
}


describe(
  "prerequisite eligibility",
  () => {
    it(
      "allows an activity with no required prerequisites",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity([]),
            new Set()
          )
        ).toBe(true);
      }
    );

    it(
      "blocks until all required skills are mastered",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity([
              "a",
              "b"
            ]),
            new Set([
              "a"
            ])
          )
        ).toBe(false);
      }
    );

    it(
      "unlocks when every required skill is mastered",
      () => {
        expect(
          isActivityPrerequisiteEligible(
            activity([
              "a",
              "b"
            ]),
            new Set([
              "a",
              "b"
            ])
          )
        ).toBe(true);
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# 7. Source-adaptive patches: exports, catalogue skillMappings,
#    selector, hooks, ActivityPlayer, and package dependency.
# ------------------------------------------------------------------
$editor = Join-Path $env:TEMP "hibeya-phase008l-editor-$runId.cjs"

WriteText $editor @'
const fs = require("fs");

const [
  learningIndexPath,
  offlineIndexPath,
  compilerPath,
  selectorPath,
  selectorTestPath,
  nextHookPath,
  playerPath,
  learnerPackagePath,
  rootPackagePath
] = process.argv.slice(2);

function read(p) {
  return fs.readFileSync(p, "utf8").replace(/\r\n/g, "\n");
}

function write(p, s) {
  fs.writeFileSync(p, s.endsWith("\n") ? s : s + "\n", "utf8");
}

function requireCondition(condition, message) {
  if (!condition) throw new Error(message);
}

let learningIndex = read(learningIndexPath);
let offlineIndex = read(offlineIndexPath);
let compiler = read(compilerPath);
let selector = read(selectorPath);
let selectorTest = fs.existsSync(selectorTestPath) ? read(selectorTestPath) : "";
let nextHook = read(nextHookPath);
let player = read(playerPath);
const learnerPkg = JSON.parse(read(learnerPackagePath));
const rootPkg = JSON.parse(read(rootPackagePath));

// learning-insights exports
requireCondition(
  learningIndex.includes('export {\n  analyseLearningSessions\n} from "./analyse";'),
  "learning-insights export anchor not found"
);

learningIndex = learningIndex.replace(
  'export {\n  analyseLearningSessions\n} from "./analyse";',
  'export {\n  analyseLearningSessions\n} from "./analyse";\n\n\nexport {\n  applySkillMasteryEvidence,\n  classifySkillMastery,\n  createEmptySkillMasteryState,\n  getMasteredSkillIds,\n  SKILL_MASTERY_POLICY\n} from "./mastery";\n\n\nexport type {\n  SkillEvidenceMapping,\n  SkillMasteryEvidenceInput,\n  SkillMasteryLevel,\n  SkillMasteryRecord,\n  SkillMasteryState\n} from "./mastery";'
);

// offline exports
requireCondition(
  offlineIndex.includes('recordCompletedJourneyActivity'),
  "offline index journey anchor not found"
);

offlineIndex += `\nexport {\n  clearLearnerSkillMasteryState,\n  getLearnerSkillMasteryState,\n  saveLearnerSkillMasteryState\n} from "./skillMastery.repository";\n\nexport type {\n  LearnerSkillMasteryState,\n  StoredSkillMasteryLevel,\n  StoredSkillMasteryRecord\n} from "./skillMastery.repository";\n`;

// compiler: emit full skill mappings in catalogue rows
const rowAnchor = `      skillIds:\n        \${jsonTs(\n          Array.from(\n            new Set(\n              manifest.skillMappings.map(\n                mapping =>\n                  mapping.skillId\n              )\n            )\n          )\n        ).replace(/\\n/g, "\\n        ")},\n\n      primarySkillIds:`;
requireCondition(
  compiler.includes(rowAnchor),
  "compiler skillIds row anchor not found"
);
compiler = compiler.replace(
  rowAnchor,
`      skillIds:\n        \${jsonTs(\n          Array.from(\n            new Set(\n              manifest.skillMappings.map(\n                mapping =>\n                  mapping.skillId\n              )\n            )\n          )\n        ).replace(/\\n/g, "\\n        ")},\n\n      skillMappings:\n        \${jsonTs(manifest.skillMappings).replace(/\\n/g, "\\n        ")},\n\n      primarySkillIds:`
);

const interfaceAnchor = `  skillIds:\n    readonly string[];\n\n  primarySkillIds:`;
requireCondition(
  compiler.includes(interfaceAnchor),
  "compiler PlayableActivity interface anchor not found"
);
compiler = compiler.replace(
  interfaceAnchor,
`  skillIds:\n    readonly string[];\n\n  skillMappings:\n    readonly {\n      skillId: string;\n      role:\n        "primary" |\n        "supporting";\n      weight: number;\n    }[];\n\n  primarySkillIds:`
);

// generated content index no longer exports removed deriveCompletedSkillIds
compiler = compiler.replace(
`export {\n  deriveCompletedSkillIds,\n  getEligibleActivitiesForLearner,\n  isActivityPrerequisiteEligible\n} from "./eligibility";`,
`export {\n  getEligibleActivitiesForLearner,\n  isActivityPrerequisiteEligible\n} from "./eligibility";`
);

// selector: masteredSkillIds becomes a required/defaulted input alongside completion
requireCondition(
  selector.includes("completedActivityIds?:"),
  "selector completedActivityIds anchor not found"
);
selector = selector.replace(
`  completedActivityIds?:\n    readonly string[];`,
`  completedActivityIds?:\n    readonly string[];\n\n  masteredSkillIds?:\n    readonly string[];`
);
selector = selector.replace(
`  completedActivityIds = []\n}: LearnerActivitySelectionInput):`,
`  completedActivityIds = [],\n  masteredSkillIds = []\n}: LearnerActivitySelectionInput):`
);
selector = selector.replace(
`      getEligibleActivitiesForLearner({\n        ageBand,\n        completedActivityIds\n      }),`,
`      getEligibleActivitiesForLearner({\n        ageBand,\n        masteredSkillIds\n      }),`
);
requireCondition(
  selector.includes("masteredSkillIds"),
  "selector mastery patch failed"
);

// selector tests are written explicitly by the PowerShell phase before
// this editor runs. Do not mutate completion inputs into mastery inputs.
// completedActivityIds controls progression; masteredSkillIds controls
// prerequisite eligibility.
// useNextLearnerActivity: load mastery IDs via service
requireCondition(
  nextHook.includes('import {\n  selectLearnerActivity\n} from "../features/play/selectLearnerActivity";'),
  "useNextLearnerActivity selector import anchor not found"
);
nextHook = nextHook.replace(
  'import {\n  selectLearnerActivity\n} from "../features/play/selectLearnerActivity";',
  'import {\n  selectLearnerActivity\n} from "../features/play/selectLearnerActivity";\n\nimport {\n  getLearnerMasteredSkillIds\n} from "../services/skillMasteryService";'
);
nextHook = nextHook.replace(
`        const [\n          journey,\n          profile\n        ] =\n          await Promise.all([\n            getLearnerJourneyState(),\n            getCachedLearnerRuntimeProfile()\n          ]);`,
`        const [\n          journey,\n          profile,\n          masteredSkillIds\n        ] =\n          await Promise.all([\n            getLearnerJourneyState(),\n            getCachedLearnerRuntimeProfile(),\n            getLearnerMasteredSkillIds()\n          ]);`
);
nextHook = nextHook.replace(
`            completedActivityIds:\n              journey.completedActivityIds\n          });`,
`            completedActivityIds:\n              journey.completedActivityIds,\n\n            masteredSkillIds\n          });`
);
requireCondition(
  nextHook.includes("masteredSkillIds"),
  "useNextLearnerActivity mastery patch failed"
);

// ActivityPlayer imports mastery service
requireCondition(
  player.includes('import {\n  localSyncProvider\n} from "../../services/localSyncProvider";'),
  "ActivityPlayer localSyncProvider import anchor not found"
);
player = player.replace(
  'import {\n  localSyncProvider\n} from "../../services/localSyncProvider";',
  'import {\n  localSyncProvider\n} from "../../services/localSyncProvider";\n\nimport {\n  getLearnerMasteredSkillIds,\n  recordSessionSkillMastery\n} from "../../services/skillMasteryService";'
);

// Internal selection path must use completion + mastery consistently.
requireCondition(
  player.includes('    const journey =\n      await getLearnerJourneyState();'),
  "ActivityPlayer journey selection anchor not found"
);
player = player.replace(
`    const journey =\n      await getLearnerJourneyState();\n\n\n    const selected =`,
`    const [\n      journey,\n      masteredSkillIds\n    ] =\n      await Promise.all([\n        getLearnerJourneyState(),\n        getLearnerMasteredSkillIds()\n      ]);\n\n\n    const selected =`
);
player = player.replace(
`        lastCompletedActivityId:\n          journey.lastCompletedActivityId\n      });`,
`        lastCompletedActivityId:\n          journey.lastCompletedActivityId,\n\n        completedActivityIds:\n          journey.completedActivityIds,\n\n        masteredSkillIds\n      });`
);

// Persist mastery exactly once after session completion and before journey completion callback.
const completionAnchor = `      await completeLocalSession(\n        sessionId,\n        result\n      );\n\n\n      await recordCompletedJourneyActivity(`;
requireCondition(
  player.includes(completionAnchor),
  "ActivityPlayer completion anchor not found"
);
player = player.replace(
  completionAnchor,
`      await completeLocalSession(\n        sessionId,\n        result\n      );\n\n\n      await recordSessionSkillMastery({\n        sessionId,\n        result,\n        skillMappings:\n          catalogue.skillMappings\n      });\n\n\n      await recordCompletedJourneyActivity(`
);

// learner-web workspace dependency
learnerPkg.dependencies ??= {};
learnerPkg.dependencies["@akal-budi/learning-insights"] = "workspace:*";

// root QA command
rootPkg.scripts ??= {};
rootPkg.scripts["mastery:validate"] = "pnpm --filter @akal-budi/learning-insights test && pnpm --filter @akal-budi/offline test && pnpm --filter @akal-budi/content-library test";

write(learningIndexPath, learningIndex);
write(offlineIndexPath, offlineIndex);
write(compilerPath, compiler);
write(selectorPath, selector);
if (selectorTest) write(selectorTestPath, selectorTest);
write(nextHookPath, nextHook);
write(playerPath, player);
write(learnerPackagePath, JSON.stringify(learnerPkg, null, 2) + "\n");
write(rootPackagePath, JSON.stringify(rootPkg, null, 2) + "\n");

console.log("PASS: exports, compiler, selector, journey hook and ActivityPlayer patched");
'@

& node `
  $editor `
  $learningIndexPath `
  $offlineIndexPath `
  $compilerPath `
  $selectorPath `
  $selectorTestPath `
  $nextHookPath `
  $playerPath `
  $learnerPackagePath `
  $rootPackagePath

if ($LASTEXITCODE -ne 0) {
  throw "Phase 008L source transformation failed."
}

Remove-Item $editor -Force -ErrorAction SilentlyContinue

Write-Host "PASS: evidence-based mastery architecture integrated" -ForegroundColor Green
Write-Host "PASS: prerequisite eligibility now consumes mastered skill IDs" -ForegroundColor Green
Write-Host "PASS: internal and journey selection paths use the same mastery state" -ForegroundColor Green

# ------------------------------------------------------------------
# 8. Recompile generated catalogue, then validate focused gates first.
# ------------------------------------------------------------------
Run "Reconcile lockfile for newly declared workspace dependency" "pnpm install --lockfile-only --no-frozen-lockfile"
Run "Verify frozen lockfile and workspace links" "pnpm install --frozen-lockfile"
Run "Compile mastery-aware content catalogue" "node tools/content-compiler/compile.mjs"
Run "Content compiler reproducibility" "pnpm content:check"

$cataloguePath = Join-Path $root "packages\content-library\src\catalogue.ts"
if (-not (Test-Path $cataloguePath)) {
  throw "Generated catalogue missing after Phase 008L compilation."
}
$catalogue = Get-Content $cataloguePath -Raw
foreach ($token in @(
  "skillMappings:",
  "requiredPrerequisiteSkillIds:"
)) {
  if ($catalogue -notmatch [Regex]::Escape($token)) {
    throw "Generated mastery catalogue postcondition failed. Missing token: $token"
  }
}
Write-Host "PASS: generated catalogue exposes weighted skill mappings" -ForegroundColor Green

Run "Learning insights mastery tests" "pnpm --filter @akal-budi/learning-insights test"
Run "Offline mastery persistence tests" "pnpm --filter @akal-budi/offline test"
Run "Content library eligibility tests" "pnpm --filter @akal-budi/content-library test"
Run "Learner selector tests" "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"

Run "Learning insights typecheck" "pnpm --filter @akal-budi/learning-insights typecheck"
Run "Offline package typecheck" "pnpm --filter @akal-budi/offline typecheck"
Run "Content library typecheck" "pnpm --filter @akal-budi/content-library typecheck"
Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner web tests" "pnpm --filter learner-web test"

Run "Content sequencing validation" "pnpm content:sequence:validate"
Run "Content eligibility validation" "pnpm content:eligibility:validate"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"

# Browser QA always uses a freshly rebuilt Storybook static output.
Run "Storybook production build" "pnpm storybook:build"
Run "Learner journey regression" "pnpm qa:journey"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression" "pnpm qa:visual"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 008L" "git add packages/learning-insights packages/offline packages/content-library tools/content-compiler apps/learner-web package.json"
  Run "Commit Phase 008L" 'git commit -m "feat: add evidence-based skill mastery"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008L: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Activity completion and skill mastery are now separate concepts." -ForegroundColor Cyan
Write-Host "Mastery uses repeated session evidence and weighted skill mappings." -ForegroundColor Cyan
Write-Host "Session evidence is idempotent by session ID." -ForegroundColor Cyan
Write-Host "Prerequisite eligibility now depends on mastered skills, not completed activities." -ForegroundColor Cyan
Write-Host "No IndexedDB schema/version migration was required." -ForegroundColor Cyan
Write-Host "No manual intervention is required." -ForegroundColor Cyan
