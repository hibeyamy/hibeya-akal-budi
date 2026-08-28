Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008o-evidence-confidence-$stamp.log"

$confidencePath = Join-Path $root "packages\learning-insights\src\masteryConfidence.ts"
$confidenceTestPath = Join-Path $root "packages\learning-insights\src\__tests__\masteryConfidence.test.ts"
$insightsIndexPath = Join-Path $root "packages\learning-insights\src\index.ts"

$resolverPath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.ts"
$resolverTestPath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.test.ts"

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
        (Join-Path $backups "$stamp-$safe") `
        -Force
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
    Log "PHASE 008O: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008O: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    Write-Host "Do not manually edit source until the log has been reviewed." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008O" -ForegroundColor Cyan
Write-Host "Evidence-Aware Mastery Confidence" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "HIBEYA AKAL BUDI - PHASE 008O"
Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

# ------------------------------------------------------------------
# 1. Verify the exact post-008N contracts before changing anything.
# ------------------------------------------------------------------

foreach ($required in @(
    (Join-Path $root "packages\learning-insights\src\mastery.ts"),
    $insightsIndexPath,
    $resolverPath,
    $resolverTestPath
)) {
    if (-not (Test-Path $required)) {
        throw "Required Phase 008O dependency missing: $required"
    }
}

$masterySource = Get-Content (Join-Path $root "packages\learning-insights\src\mastery.ts") -Raw
$indexSource = Get-Content $insightsIndexPath -Raw
$resolverSource = Get-Content $resolverPath -Raw

foreach ($token in @(
    "minimumObservations:",
    "masteryScoreThreshold:",
    "export function classifySkillMastery"
)) {
    if ($masterySource -notmatch [Regex]::Escape($token)) {
        throw "Mastery policy contract drifted. Missing token: $token"
    }
}

foreach ($token in @(
    "export interface LearnerSkillProgress",
    "export function getActivityLearningNeed",
    "export function selectRemediationActivity",
    "function rankByLearningNeed",
    "const uncompleted ="
)) {
    if ($resolverSource -notmatch [Regex]::Escape($token)) {
        throw "Phase 008N resolver contract drifted. Missing token: $token"
    }
}

if ($resolverSource -match "getEvidenceAdjustedNeed") {
    throw "Phase 008O confidence implementation already appears installed."
}

Write-Host "PASS: mastery policy and Phase 008N resolver contracts verified" -ForegroundColor Green

Backup $confidencePath
Backup $confidenceTestPath
Backup $insightsIndexPath
Backup $resolverPath
Backup $resolverTestPath

# ------------------------------------------------------------------
# 2. Add confidence policy to learning-insights.
#
# Important:
# - raw masteryScore is unchanged
# - mastery thresholds are unchanged
# - confidence is derived only from the already-defined minimumObservations
# - sparse evidence is shrunk toward neutral need (0.5), not treated as certainty
# ------------------------------------------------------------------

WriteText $confidencePath @'
import {
  SKILL_MASTERY_POLICY
} from "./mastery";


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


export function getMasteryEvidenceConfidence(
  observationCount: number
): number {
  if (
    !Number.isFinite(
      observationCount
    ) ||
    observationCount <=
      0
  ) {
    return 0;
  }

  return clamp01(
    observationCount /
      SKILL_MASTERY_POLICY.minimumObservations
  );
}


export function getEvidenceAdjustedLearningNeed({
  masteryScore,
  observationCount,
  mastered
}: {
  masteryScore: number;
  observationCount: number;
  mastered: boolean;
}): number {
  if (
    mastered
  ) {
    return 0;
  }

  const rawNeed =
    1 -
    clamp01(
      masteryScore
    );

  const confidence =
    getMasteryEvidenceConfidence(
      observationCount
    );

  const neutralNeed =
    0.5;

  return (
    neutralNeed *
      (
        1 -
        confidence
      ) +
    rawNeed *
      confidence
  );
}
'@

WriteText $confidenceTestPath @'
import {
  describe,
  expect,
  it
} from "vitest";

import {
  getEvidenceAdjustedLearningNeed,
  getMasteryEvidenceConfidence
} from "../masteryConfidence";


describe(
  "mastery evidence confidence",
  () => {
    it(
      "returns zero confidence without observations",
      () => {
        expect(
          getMasteryEvidenceConfidence(
            0
          )
        ).toBe(
          0
        );
      }
    );


    it(
      "returns partial confidence before the mastery minimum observation count",
      () => {
        expect(
          getMasteryEvidenceConfidence(
            1
          )
        ).toBe(
          0.5
        );
      }
    );


    it(
      "reaches full confidence at the existing mastery observation minimum",
      () => {
        expect(
          getMasteryEvidenceConfidence(
            2
          )
        ).toBe(
          1
        );
      }
    );


    it(
      "caps confidence for repeated observations",
      () => {
        expect(
          getMasteryEvidenceConfidence(
            12
          )
        ).toBe(
          1
        );
      }
    );


    it(
      "shrinks sparse weak evidence toward neutral need",
      () => {
        expect(
          getEvidenceAdjustedLearningNeed({
            masteryScore:
              0.1,
            observationCount:
              1,
            mastered:
              false
          })
        ).toBeCloseTo(
          0.7
        );
      }
    );


    it(
      "uses full raw learning need once evidence is sufficient",
      () => {
        expect(
          getEvidenceAdjustedLearningNeed({
            masteryScore:
              0.1,
            observationCount:
              2,
            mastered:
              false
          })
        ).toBeCloseTo(
          0.9
        );
      }
    );


    it(
      "keeps mastered skills at zero need",
      () => {
        expect(
          getEvidenceAdjustedLearningNeed({
            masteryScore:
              0.75,
            observationCount:
              2,
            mastered:
              true
          })
        ).toBe(
          0
        );
      }
    );
  }
);
'@

# ------------------------------------------------------------------
# 3. Export confidence helpers without assuming an exact index layout.
# ------------------------------------------------------------------

$indexSource = Get-Content $insightsIndexPath -Raw

if ($indexSource -notmatch "getMasteryEvidenceConfidence") {
    $append = @'

export {
  getEvidenceAdjustedLearningNeed,
  getMasteryEvidenceConfidence
} from "./masteryConfidence";
'@

    WriteText $insightsIndexPath ($indexSource.TrimEnd() + $append)
}

$indexCheck = Get-Content $insightsIndexPath -Raw

foreach ($token in @(
    "getEvidenceAdjustedLearningNeed",
    "getMasteryEvidenceConfidence",
    '"./masteryConfidence"'
)) {
    if ($indexCheck -notmatch [Regex]::Escape($token)) {
        throw "learning-insights confidence export failed. Missing token: $token"
    }
}

Write-Host "PASS: evidence-confidence policy added to learning-insights" -ForegroundColor Green

# ------------------------------------------------------------------
# 4. Patch only the learning-need calculation in the shared resolver.
#    Eligibility, unfinished-first, remediation ordering, and tie-breaks stay intact.
# ------------------------------------------------------------------

$resolverSource = Get-Content $resolverPath -Raw

$importAnchor = @'
import type {
  ResolvedPlayableActivity
} from "@akal-budi/content-library";
'@

$replacementImport = @'
import type {
  ResolvedPlayableActivity
} from "@akal-budi/content-library";

import {
  getEvidenceAdjustedLearningNeed
} from "@akal-budi/learning-insights";
'@

if (-not $resolverSource.Contains($importAnchor)) {
    throw "Resolver content-library import anchor not found."
}

$resolverSource = $resolverSource.Replace(
    $importAnchor,
    $replacementImport
)

$oldSkillNeed = @'
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
'@

$newSkillNeed = @'
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

  return getEvidenceAdjustedLearningNeed({
    masteryScore:
      record.masteryScore,

    observationCount:
      record.observationCount,

    mastered:
      record.level ===
        "mastered"
  });
}
'@

if (-not $resolverSource.Contains($oldSkillNeed)) {
    throw "Phase 008N getSkillNeed implementation anchor not found."
}

$resolverSource = $resolverSource.Replace(
    $oldSkillNeed,
    $newSkillNeed
)

# clamp01 is no longer needed in the resolver after delegation.
$oldClamp = @'
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


'@

if ($resolverSource.Contains($oldClamp)) {
    $resolverSource = $resolverSource.Replace(
        $oldClamp,
        ""
    )
}

WriteText $resolverPath $resolverSource

$resolverCheck = Get-Content $resolverPath -Raw

foreach ($token in @(
    "getEvidenceAdjustedLearningNeed",
    "observationCount:",
    "export function selectRemediationActivity",
    "const uncompleted =",
    "rankByLearningNeed("
)) {
    if ($resolverCheck -notmatch [Regex]::Escape($token)) {
        throw "Resolver confidence integration postcondition failed. Missing token: $token"
    }
}

Write-Host "PASS: sparse evidence now influences ranking conservatively" -ForegroundColor Green
Write-Host "PASS: raw mastery score and prerequisite mastery semantics remain unchanged" -ForegroundColor Green
Write-Host "PASS: unfinished-first and deterministic remediation contracts remain intact" -ForegroundColor Green

# ------------------------------------------------------------------
# 5. Add focused resolver tests for evidence sufficiency without replacing
#    the existing 008N coverage.
# ------------------------------------------------------------------

$resolverTests = Get-Content $resolverTestPath -Raw

if ($resolverTests -notmatch "prefers sufficiently observed weakness over a single sparse weak observation") {
    $insertBefore = "`n  }`n);"

    $lastIndex = $resolverTests.LastIndexOf($insertBefore)

    if ($lastIndex -lt 0) {
        throw "Could not locate final resolver test-suite boundary."
    }

    $newTests = @'


    it(
      "prefers sufficiently observed weakness over a single sparse weak observation",
      () => {
        const sparseWeak =
          activity(
            "sparse-weak",
            10,
            "skill-sparse"
          );

        const establishedWeak =
          activity(
            "established-weak",
            20,
            "skill-established"
          );

        expect(
          resolveNextLearnerActivity({
            activities: [
              sparseWeak,
              establishedWeak
            ],
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress: [
              {
                skillId:
                  "skill-sparse",
                masteryScore:
                  0.1,
                observationCount:
                  1,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-established",
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
          "established-weak"
        );
      }
    );


    it(
      "uses raw need once both skills have sufficient evidence",
      () => {
        const weaker =
          activity(
            "weaker",
            10,
            "skill-weaker"
          );

        const stronger =
          activity(
            "stronger",
            20,
            "skill-stronger"
          );

        expect(
          resolveNextLearnerActivity({
            activities: [
              stronger,
              weaker
            ],
            completedActivityIds:
              [],
            lastCompletedActivityId:
              null,
            skillProgress: [
              {
                skillId:
                  "skill-weaker",
                masteryScore:
                  0.1,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-stronger",
                masteryScore:
                  0.3,
                observationCount:
                  2,
                level:
                  "exploring"
              }
            ]
          })?.id
        ).toBe(
          "weaker"
        );
      }
    );
'@

    $resolverTests =
        $resolverTests.Substring(0, $lastIndex) +
        $newTests +
        $resolverTests.Substring($lastIndex)

    WriteText $resolverTestPath $resolverTests
}

Write-Host "PASS: evidence-sufficiency resolver tests installed" -ForegroundColor Green

# ------------------------------------------------------------------
# 6. Focused gates first, then complete repository validation.
# ------------------------------------------------------------------

Invoke-NativeStep `
    "Mastery confidence tests" `
    "pnpm --filter @akal-budi/learning-insights exec vitest run src/__tests__/masteryConfidence.test.ts"

Invoke-NativeStep `
    "Adaptive/remediation resolver tests" `
    "pnpm --filter learner-web exec vitest run src/journey/nextLearnerActivity.service.test.ts"

Invoke-NativeStep `
    "Learning insights typecheck" `
    "pnpm --filter @akal-budi/learning-insights typecheck"

Invoke-NativeStep `
    "Learner web typecheck" `
    "pnpm --filter learner-web typecheck"

Invoke-NativeStep `
    "Learning insights tests" `
    "pnpm --filter @akal-budi/learning-insights test"

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
Write-Host "PHASE 008O: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Sparse evidence is now shrunk toward neutral learning need." -ForegroundColor Cyan
Write-Host "Evidence confidence reaches full weight at the existing mastery minimum observation count." -ForegroundColor Cyan
Write-Host "Mastery thresholds, prerequisite unlocking, unfinished-first progression, and remediation contracts are unchanged." -ForegroundColor Cyan
Write-Host "No schema, persistence, manifest, curriculum, dependency, or lockfile migration was required." -ForegroundColor Cyan
Write-Host "Log: $log" -ForegroundColor White
