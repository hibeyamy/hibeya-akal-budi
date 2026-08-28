param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

$repoPath = Join-Path $root "packages\offline\src\learningJourney.repository.ts"
$testPath = Join-Path $root "packages\offline\src\__tests__\learningJourney.repository.test.ts"
$progressPath = Join-Path $root "apps\learner-web\src\journey\learnerProgress.ts"
$progressTestPath = Join-Path $root "apps\learner-web\src\journey\learnerProgress.test.ts"
$hookPath = Join-Path $root "apps\learner-web\src\journey\useLearnerProgress.ts"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008h-repair-v2-$runId.log"

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

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008h-repair-v2-$stamp-out.log"
  $err = Join-Path $logs "phase008h-repair-v2-$stamp-err.log"

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

  if ($stdout) {
    Write-Host $stdout
    Add-Content $log $stdout -Encoding UTF8
  }

  if ($stderr) {
    Write-Host $stderr
    Add-Content $log $stderr -Encoding UTF8
  }

  if ($process.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase008h-repair-v2-$stamp-$($Name.Replace(' ','-')).log"
    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
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
  Write-Host "PHASE 008H REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  Write-Host "Do not make manual source edits unless explicitly requested after log review." -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008H REPAIR V2" -ForegroundColor Cyan
Write-Host "Exact repository contract + atomic source transformation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($required in @(
  $repoPath,
  $testPath,
  $progressPath,
  $progressTestPath,
  $hookPath
)) {
  if (-not (Test-Path $required)) {
    throw "Required file missing: $required"
  }
}

# Verified from the preflight report:
# getLearnerJourneyState() currently does:
#   if (!stored || !isJourneyState(stored.value)) return { ...emptyJourney };
#   return stored.value;
#
# The failed V1 assumed a null-coalescing return that does not exist.
$repoSource = Get-Content $repoPath -Raw

foreach ($token in @(
  "return stored.value;",
  "isJourneyState(",
  "const emptyJourney:",
  "completedSessionCount:",
  "recordCompletedJourneyActivity("
)) {
  if ($repoSource -notmatch [Regex]::Escape($token)) {
    throw "Verified repository contract has drifted. Missing token: $token"
  }
}

Write-Host "PASS: exact learningJourney.repository.ts contract verified" -ForegroundColor Green

foreach ($path in @(
  $repoPath,
  $testPath,
  $progressPath,
  $progressTestPath,
  $hookPath
)) {
  Backup $path
}

$editor = Join-Path $env:TEMP "hibeya-phase008h-repair-v2-$runId.cjs"

WriteText $editor @'
const fs = require("fs");

const [
  repoPath,
  testPath,
  progressPath,
  progressTestPath,
  hookPath
] = process.argv.slice(2);

function read(file) {
  return fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
}

function requireCondition(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const original = {
  repo: read(repoPath),
  tests: read(testPath),
  progress: read(progressPath),
  progressTests: read(progressTestPath),
  hook: read(hookPath)
};

let repo = original.repo;
let tests = original.tests;
let hook = original.hook;

// ------------------------------------------------------------
// Repository transformation
// ------------------------------------------------------------

requireCondition(
  !repo.includes("completedActivityIds"),
  "Repository already contains completedActivityIds. Stop and inspect current state before applying this repair."
);

repo = repo.replace(
  /(export interface LearnerJourneyState\s*\{[\s\S]*?completedSessionCount\s*:\s*number\s*;)/m,
  `$1

  completedActivityIds:
    string[];`
);

requireCondition(
  repo.includes("completedActivityIds:"),
  "Could not extend LearnerJourneyState."
);

repo = repo.replace(
  /(const emptyJourney\s*:\s*LearnerJourneyState\s*=\s*\{[\s\S]*?completedSessionCount\s*:\s*0\s*,)/m,
  `$1

    completedActivityIds:
      [],`
);

requireCondition(
  /completedActivityIds\s*:\s*\[\]/m.test(repo),
  "Could not extend emptyJourney."
);

// The actual current read boundary is exactly `return stored.value;`.
repo = repo.replace(
  /(\n\s*)return stored\.value;/m,
  `$1return normalizeJourneyState(
    stored.value
  );`
);

requireCondition(
  !repo.includes("return stored.value;"),
  "Could not replace the verified stored.value return boundary."
);

// Change the validator's output type to a legacy-compatible shape.
repo = repo.replace(
  /function isJourneyState\(\s*value:\s*unknown\s*\)\s*:\s*value is LearnerJourneyState\s*\{/m,
  `interface LegacyLearnerJourneyState {
  lastCompletedActivityId:
    string | null;

  completedSessionCount:
    number;

  completedActivityIds?:
    unknown;

  updatedAt:
    number;
}


function normalizeJourneyState(
  value:
    LegacyLearnerJourneyState
):
  LearnerJourneyState {
  const storedIds =
    Array.isArray(
      value.completedActivityIds
    )
      ? value.completedActivityIds.filter(
          (
            candidate
          ): candidate is string =>
            typeof candidate ===
              "string" &&
            candidate.length >
              0
        )
      : [];

  const completedActivityIds =
    storedIds.length >
      0
      ? Array.from(
          new Set(
            storedIds
          )
        )
      : value.lastCompletedActivityId
        ? [
            value.lastCompletedActivityId
          ]
        : [];

  return {
    lastCompletedActivityId:
      value.lastCompletedActivityId,

    completedSessionCount:
      value.completedSessionCount,

    completedActivityIds,

    updatedAt:
      value.updatedAt
  };
}


function isJourneyState(
  value: unknown
): value is LegacyLearnerJourneyState {`
);

requireCondition(
  repo.includes("interface LegacyLearnerJourneyState"),
  "Could not install legacy-compatible journey normaliser."
);

// Extend the completion update while keeping raw session count behaviour.
const nextStatePattern =
  /const next\s*:\s*LearnerJourneyState\s*=\s*\{[\s\S]*?lastCompletedActivityId\s*:\s*activityId\s*,[\s\S]*?completedSessionCount\s*:\s*current\.completedSessionCount\s*\+\s*1\s*,[\s\S]*?updatedAt\s*:\s*Date\.now\(\)\s*\n?\s*\};/m;

requireCondition(
  nextStatePattern.test(repo),
  "Could not locate the verified completion state update."
);

repo = repo.replace(
  nextStatePattern,
`const completedActivityIds =
    current.completedActivityIds.includes(
      activityId
    )
      ? current.completedActivityIds
      : [
          ...current.completedActivityIds,
          activityId
        ];

  const next:
    LearnerJourneyState = {
      lastCompletedActivityId:
        activityId,

      completedSessionCount:
        current.completedSessionCount +
        1,

      completedActivityIds,

      updatedAt:
        Date.now()
    };`
);

// ------------------------------------------------------------
// Existing repository tests
// ------------------------------------------------------------

// Both "starts empty" and "clears state" expect the complete object.
const emptyExpectationPattern =
  /(completedSessionCount\s*:\s*0\s*,)(\s*\n\s*updatedAt\s*:)/g;

let emptyMatches = 0;

tests = tests.replace(
  emptyExpectationPattern,
  (...args) => {
    emptyMatches += 1;

    return `${args[1]}

          completedActivityIds:
            [],${args[2]}`;
  }
);

requireCondition(
  emptyMatches >= 2,
  `Expected at least two empty-state assertions; found ${emptyMatches}.`
);

// Existing records-completion assertion.
const completionAssertion =
  /expect\(\s*state\.completedSessionCount\s*\)\.toBe\(1\);/m;

requireCondition(
  completionAssertion.test(tests),
  "Could not locate existing records-completion assertion."
);

tests = tests.replace(
  completionAssertion,
`expect(
          state.completedSessionCount
        ).toBe(1);

        expect(
          state.completedActivityIds
        ).toEqual([
          "warna-bunga-raya-001"
        ]);`
);

// Add repeat/distinct behaviour before the known clears-state test.
const clearsBoundary =
  /\n\s*it\(\s*"clears state"\s*,/m;

requireCondition(
  clearsBoundary.test(tests),
  "Could not locate the verified clears-state test boundary."
);

tests = tests.replace(
  clearsBoundary,
`
    it(
      "does not duplicate unique completion when an activity is replayed",
      async () => {
        await recordCompletedJourneyActivity(
          "warna-bunga-raya-001"
        );

        const state =
          await recordCompletedJourneyActivity(
            "warna-bunga-raya-001"
          );

        expect(
          state.completedSessionCount
        ).toBe(2);

        expect(
          state.completedActivityIds
        ).toEqual([
          "warna-bunga-raya-001"
        ]);
      }
    );


    it(
      "tracks distinct completed activities",
      async () => {
        await recordCompletedJourneyActivity(
          "warna-bunga-raya-001"
        );

        const state =
          await recordCompletedJourneyActivity(
            "warna-merah-001"
          );

        expect(
          state.completedSessionCount
        ).toBe(2);

        expect(
          state.completedActivityIds
        ).toEqual([
          "warna-bunga-raya-001",
          "warna-merah-001"
        ]);
      }
    );
` + tests.match(clearsBoundary)[0]
);

// ------------------------------------------------------------
// Progress model
// ------------------------------------------------------------

const progress = `export interface LearnerProgressInput {
  completedActivityIds:
    readonly string[];

  playableActivityIds:
    readonly string[];
}

export function calculateLearnerProgressPercent({
  completedActivityIds,
  playableActivityIds
}: LearnerProgressInput):
  number {
  const playable =
    new Set(
      playableActivityIds.filter(
        id =>
          typeof id ===
            "string" &&
          id.length >
            0
      )
    );

  if (
    playable.size ===
      0
  ) {
    return 0;
  }

  const completed =
    new Set(
      completedActivityIds.filter(
        id =>
          playable.has(
            id
          )
      )
    );

  return Math.min(
    100,
    Math.round(
      (
        completed.size /
        playable.size
      ) *
      100
    )
  );
}
`;

const progressTests = `import {
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
            completedActivityIds:
              [],
            playableActivityIds:
              ["a", "b"]
          })
        ).toBe(0);
      }
    );

    it(
      "counts replayed activities only once",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedActivityIds:
              ["a", "a"],
            playableActivityIds:
              ["a", "b"]
          })
        ).toBe(50);
      }
    );

    it(
      "ignores completion IDs outside the current playable set",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedActivityIds:
              ["a", "legacy"],
            playableActivityIds:
              ["a", "b"]
          })
        ).toBe(50);
      }
    );

    it(
      "returns one hundred when all playable activities are complete",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedActivityIds:
              ["a", "b", "b"],
            playableActivityIds:
              ["a", "b"]
          })
        ).toBe(100);
      }
    );

    it(
      "returns zero when no playable activities exist",
      () => {
        expect(
          calculateLearnerProgressPercent({
            completedActivityIds:
              ["a"],
            playableActivityIds:
              []
          })
        ).toBe(0);
      }
    );
  }
);
`;

// ------------------------------------------------------------
// Progress hook
// ------------------------------------------------------------

const oldHookContract =
  /completedSessionCount\s*:\s*journey\.completedSessionCount\s*,\s*playableActivityCount\s*:\s*playable\.length/m;

requireCondition(
  oldHookContract.test(hook),
  "Could not locate Phase 008G session-count progress contract."
);

hook = hook.replace(
  oldHookContract,
`completedActivityIds:
              journey.completedActivityIds,

            playableActivityIds:
              playable.map(
                activity =>
                  activity.id
              )`
);

requireCondition(
  !hook.includes("playableActivityCount:"),
  "Old playableActivityCount contract remains after transformation."
);

// ------------------------------------------------------------
// Atomic postcondition validation BEFORE writing anything.
// ------------------------------------------------------------

for (const [name, source] of Object.entries({
  repo,
  tests,
  progress,
  progressTests,
  hook
})) {
  requireCondition(
    typeof source === "string" && source.length > 0,
    `${name} transformation produced empty output.`
  );
}

requireCondition(
  repo.includes("return normalizeJourneyState("),
  "Repository normalisation postcondition failed."
);

requireCondition(
  repo.includes("completedActivityIds,"),
  "Repository unique completion update postcondition failed."
);

requireCondition(
  tests.includes("does not duplicate unique completion"),
  "Repository duplicate-completion test postcondition failed."
);

requireCondition(
  hook.includes("journey.completedActivityIds"),
  "Progress hook postcondition failed."
);

// Only now write all transformed files.
fs.writeFileSync(repoPath, repo.endsWith("\n") ? repo : repo + "\n", "utf8");
fs.writeFileSync(testPath, tests.endsWith("\n") ? tests : tests + "\n", "utf8");
fs.writeFileSync(progressPath, progress, "utf8");
fs.writeFileSync(progressTestPath, progressTests, "utf8");
fs.writeFileSync(hookPath, hook.endsWith("\n") ? hook : hook + "\n", "utf8");

console.log("PASS: atomic Phase 008H source transformation complete");
'@

& node `
  $editor `
  $repoPath `
  $testPath `
  $progressPath `
  $progressTestPath `
  $hookPath

if ($LASTEXITCODE -ne 0) {
  throw "Atomic Phase 008H source transformation failed."
}

Remove-Item $editor -Force -ErrorAction SilentlyContinue

Write-Host "PASS: source transformation completed" -ForegroundColor Green
Write-Host "PASS: legacy journey state is normalised without database reset" -ForegroundColor Green
Write-Host "PASS: replayed activities no longer inflate progress" -ForegroundColor Green

# Targeted gates first.
Run "Offline journey repository tests" "pnpm --filter @akal-budi/offline exec vitest run src/__tests__/learningJourney.repository.test.ts"
Run "Offline package typecheck" "pnpm --filter @akal-budi/offline typecheck"
Run "Learner progress tests" "pnpm --filter learner-web exec vitest run src/journey/learnerProgress.test.ts"
Run "Learner web typecheck" "pnpm --filter learner-web typecheck"

# Full regression.
Run "Offline package tests" "pnpm --filter @akal-budi/offline test"
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Storybook production build" "pnpm storybook:build"
Run "Learner journey E2E" "pnpm qa:journey"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression" "pnpm qa:visual"
Run "Content compiler check" "pnpm content:check"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run `
    "Stage Phase 008H Repair V2" `
    "git add packages/offline/src/learningJourney.repository.ts packages/offline/src/__tests__/learningJourney.repository.test.ts apps/learner-web/src/journey/learnerProgress.ts apps/learner-web/src/journey/learnerProgress.test.ts apps/learner-web/src/journey/useLearnerProgress.ts"

  Run `
    "Commit Phase 008H Repair V2" `
    'git commit -m "feat: track unique learner activity completion"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008H REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No manual intervention was required." -ForegroundColor Cyan
Write-Host "No IndexedDB store/version migration was introduced." -ForegroundColor Cyan
