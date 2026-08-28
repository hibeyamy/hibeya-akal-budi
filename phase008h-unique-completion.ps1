param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008h-unique-completion-$stamp.txt"

$repoPath = Join-Path $root "packages\offline\src\learningJourney.repository.ts"
$testPath = Join-Path $root "packages\offline\src\__tests__\learningJourney.repository.test.ts"
$progressPath = Join-Path $root "apps\learner-web\src\journey\learnerProgress.ts"
$progressTestPath = Join-Path $root "apps\learner-web\src\journey\learnerProgress.test.ts"
$hookPath = Join-Path $root "apps\learner-web\src\journey\useLearnerProgress.ts"

function Log([string]$Text = "") {
    Add-Content -Path $log -Value $Text -Encoding UTF8
}

function Backup([string]$Path) {
    if (Test-Path $Path) {
        $name = Split-Path $Path -Leaf
        Copy-Item $Path (Join-Path $backups "$stamp-$name") -Force
    }
}

function Run([string]$Name,[string]$Command) {
    Write-Host "==> $Name" -ForegroundColor Cyan
    Log ""
    Log "==> $Name"
    Log $Command

    $out = Join-Path $env:TEMP "hibeya-008h-$stamp-out.txt"
    $err = Join-Path $env:TEMP "hibeya-008h-$stamp-err.txt"

    $p = Start-Process `
        -FilePath "cmd.exe" `
        -ArgumentList "/d","/s","/c",$Command `
        -WorkingDirectory $root `
        -RedirectStandardOutput $out `
        -RedirectStandardError $err `
        -Wait `
        -PassThru `
        -NoNewWindow

    if (Test-Path $out) { Get-Content $out | ForEach-Object { Log $_ } }
    if (Test-Path $err) { Get-Content $err | ForEach-Object { Log $_ } }

    if ($p.ExitCode -ne 0) {
        throw "$Name failed with exit code $($p.ExitCode)."
    }

    Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Log ""
    Log "FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Write-Host ""
    Write-Host "PHASE 008H: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008H" -ForegroundColor Cyan
Write-Host "Unique Completion + Progress Integrity" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($required in @($repoPath,$testPath,$progressPath,$progressTestPath,$hookPath)) {
    if (-not (Test-Path $required)) { throw "Required file missing: $required" }
}

# Contract checks: refuse to patch an unexpected repository.
$repo = Get-Content $repoPath -Raw
foreach ($token in @(
    "export interface LearnerJourneyState",
    "lastCompletedActivityId",
    "completedSessionCount",
    "recordCompletedJourneyActivity",
    "current.completedSessionCount"
)) {
    if ($repo -notmatch [Regex]::Escape($token)) {
        throw "Offline journey contract drifted. Missing token: $token"
    }
}

Backup $repoPath
Backup $testPath
Backup $progressPath
Backup $progressTestPath
Backup $hookPath

# Use a source-adaptive Node editor rather than assuming formatting.
$editor = Join-Path $env:TEMP "hibeya-008h-editor-$stamp.cjs"

@'
const fs = require("fs");

const [repoPath,testPath,progressPath,progressTestPath,hookPath] =
  process.argv.slice(2);

function read(p) {
  return fs.readFileSync(p, "utf8").replace(/\r\n/g, "\n");
}
function write(p,s) {
  fs.writeFileSync(p, s.endsWith("\n") ? s : s + "\n", "utf8");
}

let repo = read(repoPath);

// 1. Add completedActivityIds to the persisted value shape.
// This does not require an IndexedDB schema/version change because the existing
// journey record remains in the same store/key; only the serialised object grows.
if (!repo.includes("completedActivityIds")) {
  repo = repo.replace(
    /(completedSessionCount\s*:\s*number\s*;)/,
    `$1\n\n  completedActivityIds:\n    string[];`
  );

  repo = repo.replace(
    /(completedSessionCount\s*:\s*0\s*,)/,
    `$1\n\n    completedActivityIds:\n      [],`
  );

  // Normalise legacy records on read. Existing installs may not have the field.
  const returnMatch = /return\s*\(\s*stored\s*\?\?\s*createEmptyLearnerJourneyState\(\)\s*\)\s*;/m;
  if (returnMatch.test(repo)) {
    repo = repo.replace(
      returnMatch,
`if (!stored) {
    return createEmptyLearnerJourneyState();
  }

  return {
    ...stored,
    completedActivityIds:
      Array.isArray(
        (stored as Partial<LearnerJourneyState>)
          .completedActivityIds
      )
        ? Array.from(
            new Set(
              (stored as Partial<LearnerJourneyState>)
                .completedActivityIds
                ?.filter(
                  (
                    value
                  ): value is string =>
                    typeof value ===
                      "string" &&
                    value.length >
                      0
                ) ??
                []
            )
          )
        : []
  };`
    );
  } else {
    // More general fallback: locate a direct stored/default return.
    const alt = /return\s+stored\s*\?\?\s*createEmptyLearnerJourneyState\(\)\s*;/m;
    if (!alt.test(repo)) {
      throw new Error("Could not locate journey read return boundary.");
    }
    repo = repo.replace(
      alt,
`if (!stored) {
    return createEmptyLearnerJourneyState();
  }

  return {
    ...stored,
    completedActivityIds:
      Array.isArray(
        (stored as Partial<LearnerJourneyState>)
          .completedActivityIds
      )
        ? Array.from(
            new Set(
              (stored as Partial<LearnerJourneyState>)
                .completedActivityIds
                ?.filter(
                  (
                    value
                  ): value is string =>
                    typeof value ===
                      "string" &&
                    value.length >
                      0
                ) ??
                []
            )
          )
        : []
  };`
    );
  }

  // Replace the old unconditional counter update with idempotent unique tracking.
  const counter = /const next\s*:\s*LearnerJourneyState\s*=\s*\{[\s\S]*?lastCompletedActivityId\s*:\s*activityId\s*,[\s\S]*?completedSessionCount\s*:\s*current\.completedSessionCount\s*\+\s*1\s*,[\s\S]*?updatedAt\s*:\s*Date\.now\(\)\s*\n?\s*\};/m;
  if (!counter.test(repo)) {
    throw new Error("Could not locate completion state update boundary.");
  }

  repo = repo.replace(
    counter,
`const alreadyCompleted =
    current.completedActivityIds.includes(
      activityId
    );

  const completedActivityIds =
    alreadyCompleted
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
}

write(repoPath, repo);

// 2. Replace repository tests with explicit backward-compatible integrity tests.
let tests = read(testPath);

if (!tests.includes("does not duplicate unique completion")) {
  tests = tests.replace(
    /completedSessionCount\s*:\s*0\s*,/g,
    `completedSessionCount:\n            0,\n\n          completedActivityIds:\n            [],`
  );

  // Add expectations to the existing "records completion" test.
  const completionExpectation =
    /expect\(\s*state\.completedSessionCount\s*\)\.toBe\(1\);/m;
  if (!completionExpectation.test(tests)) {
    throw new Error("Could not locate repository completion test assertion.");
  }

  tests = tests.replace(
    completionExpectation,
`expect(
          state.completedSessionCount
        ).toBe(1);

        expect(
          state.completedActivityIds
        ).toEqual([
          "warna-bunga-raya-001"
        ]);`
  );

  // Insert before the clears-state test.
  const clearBoundary = /\n\s*it\(\s*"clears state"/m;
  if (!clearBoundary.test(tests)) {
    throw new Error("Could not locate clears-state test boundary.");
  }

  tests = tests.replace(
    clearBoundary,
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
` + tests.match(clearBoundary)[0]
  );
}

write(testPath, tests);

// 3. Progress is now based on unique eligible completions, not raw sessions.
let progress = `export interface LearnerProgressInput {
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
      playableActivityIds
        .filter(
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
      completedActivityIds
        .filter(
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
write(progressPath, progress);

let progressTests = `import {
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
      "calculates progress from unique eligible activities",
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
      "ignores completions outside the current playable set",
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
      "returns one hundred when every playable activity is complete",
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
write(progressTestPath, progressTests);

let hook = read(hookPath);
hook = hook.replace(
  /completedSessionCount\s*:\s*journey\.completedSessionCount\s*,\s*playableActivityCount\s*:\s*playable\.length/m,
`completedActivityIds:
              journey.completedActivityIds,

            playableActivityIds:
              playable.map(
                activity =>
                  activity.id
              )`
);

if (hook.includes("completedSessionCount:") || hook.includes("playableActivityCount:")) {
  throw new Error("Learner progress hook still contains the old session-count contract.");
}
write(hookPath, hook);
'@ | Set-Content -Path $editor -Encoding UTF8

& node $editor $repoPath $testPath $progressPath $progressTestPath $hookPath
if ($LASTEXITCODE -ne 0) {
    throw "Phase 008H source editor failed."
}
Remove-Item $editor -Force -ErrorAction SilentlyContinue

Write-Host "PASS: unique completion persistence integrated" -ForegroundColor Green
Write-Host "PASS: progress now uses unique eligible activity IDs" -ForegroundColor Green

Run "Offline package tests" "pnpm --filter @akal-budi/offline test"
Run "Offline package typecheck" "pnpm --filter @akal-budi/offline typecheck"
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
    Run "Stage Phase 008H" "git add packages/offline/src/learningJourney.repository.ts packages/offline/src/__tests__/learningJourney.repository.test.ts apps/learner-web/src/journey/learnerProgress.ts apps/learner-web/src/journey/learnerProgress.test.ts apps/learner-web/src/journey/useLearnerProgress.ts"
    Run "Commit Phase 008H" 'git commit -m "feat: track unique learner activity completion"'
}

Log ""
Log "PHASE 008H: PASS $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008H: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Unique activity completion is now idempotent for progress." -ForegroundColor Cyan
Write-Host "Raw completedSessionCount remains available as a session metric." -ForegroundColor Cyan
Write-Host "No IndexedDB version/store migration was introduced." -ForegroundColor Cyan
Write-Host "Log: $log" -ForegroundColor DarkGray
