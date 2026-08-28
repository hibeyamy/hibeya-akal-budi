Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008p-activity-diversity-$stamp.log"

$resolverPath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.ts"
$resolverTestPath = Join-Path $root "apps\learner-web\src\journey\nextLearnerActivity.service.test.ts"

function WriteText([string]$Path,[string]$Content) {
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
        $text = if ($line -is [System.Management.Automation.ErrorRecord]) {
            $line.Exception.Message
        } else {
            [string]$line
        }
        Write-Host $text
        Log $text
    }

    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode"
    }

    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Log ""
    Log "PHASE 008P: FAILED"
    Log ($_ | Out-String)
    Write-Host ""
    Write-Host "PHASE 008P: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008P" -ForegroundColor Cyan
Write-Host "Deterministic Activity Diversity / Anti-Repetition" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($required in @($resolverPath,$resolverTestPath)) {
    if (-not (Test-Path $required)) {
        throw "Required file missing: $required"
    }
}

$resolver = Get-Content $resolverPath -Raw

foreach ($token in @(
    "getEvidenceAdjustedLearningNeed",
    "function rankByLearningNeed",
    "export function selectRemediationActivity",
    "const uncompleted =",
    "lastCompletedActivityId:"
)) {
    if ($resolver -notmatch [Regex]::Escape($token)) {
        throw "Post-008O resolver contract drifted. Missing token: $token"
    }
}

if ($resolver -match "avoidActivityId") {
    throw "Phase 008P already appears installed."
}

Backup $resolverPath
Backup $resolverTestPath

$oldRankSignature = @'
function rankByLearningNeed(
  candidates:
    readonly ResolvedPlayableActivity[],
  catalogue:
    readonly ResolvedPlayableActivity[],
  skillProgress:
    readonly LearnerSkillProgress[]
):
  ResolvedPlayableActivity[] {
'@

$newRankSignature = @'
function rankByLearningNeed(
  candidates:
    readonly ResolvedPlayableActivity[],
  catalogue:
    readonly ResolvedPlayableActivity[],
  skillProgress:
    readonly LearnerSkillProgress[],
  avoidActivityId:
    string | null = null
):
  ResolvedPlayableActivity[] {
'@

if (-not $resolver.Contains($oldRankSignature)) {
    throw "rankByLearningNeed signature anchor not found."
}
$resolver = $resolver.Replace($oldRankSignature,$newRankSignature)

$oldNeedBoundary = @'
        if (
          Math.abs(
            needDifference
          ) >
            0.000001
        ) {
          return needDifference;
        }

        const sequenceDifference =
'@

$newNeedBoundary = @'
        if (
          Math.abs(
            needDifference
          ) >
            0.000001
        ) {
          return needDifference;
        }

        if (
          avoidActivityId
        ) {
          const leftIsImmediateRepeat =
            left.id ===
              avoidActivityId;

          const rightIsImmediateRepeat =
            right.id ===
              avoidActivityId;

          if (
            leftIsImmediateRepeat !==
              rightIsImmediateRepeat
          ) {
            return leftIsImmediateRepeat
              ? 1
              : -1;
          }
        }

        const sequenceDifference =
'@

if (-not $resolver.Contains($oldNeedBoundary)) {
    throw "Comparator anchor not found."
}
$resolver = $resolver.Replace($oldNeedBoundary,$newNeedBoundary)

$oldRemediationSignature = @'
export function selectRemediationActivity({
  activities,
  skillProgress
}: {
  activities:
    readonly ResolvedPlayableActivity[];

  skillProgress:
    readonly LearnerSkillProgress[];
}):
'@

$newRemediationSignature = @'
export function selectRemediationActivity({
  activities,
  skillProgress,
  lastCompletedActivityId = null
}: {
  activities:
    readonly ResolvedPlayableActivity[];

  skillProgress:
    readonly LearnerSkillProgress[];

  lastCompletedActivityId?:
    string | null;
}):
'@

if (-not $resolver.Contains($oldRemediationSignature)) {
    throw "selectRemediationActivity signature anchor not found."
}
$resolver = $resolver.Replace($oldRemediationSignature,$newRemediationSignature)

$oldRankCall = @'
  const ranked =
    rankByLearningNeed(
      activities,
      activities,
      skillProgress
    );
'@

$newRankCall = @'
  const ranked =
    rankByLearningNeed(
      activities,
      activities,
      skillProgress,
      lastCompletedActivityId
    );
'@

if (-not $resolver.Contains($oldRankCall)) {
    throw "Remediation rank call anchor not found."
}
$resolver = $resolver.Replace($oldRankCall,$newRankCall)

$oldResolveCall = @'
  const remediation =
    selectRemediationActivity({
      activities,
      skillProgress
    });
'@

$newResolveCall = @'
  const remediation =
    selectRemediationActivity({
      activities,
      skillProgress,
      lastCompletedActivityId
    });
'@

if (-not $resolver.Contains($oldResolveCall)) {
    throw "Resolver remediation call anchor not found."
}
$resolver = $resolver.Replace($oldResolveCall,$newResolveCall)

WriteText $resolverPath $resolver

$tests = Get-Content $resolverTestPath -Raw

if ($tests -notmatch "avoids immediate remediation repetition when learning need is equal") {
    $insertBefore = "`n  }`n);"
    $lastIndex = $tests.LastIndexOf($insertBefore)
    if ($lastIndex -lt 0) {
        throw "Could not locate final test-suite boundary."
    }

    $newTests = @'


    it(
      "avoids immediate remediation repetition when learning need is equal",
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

        expect(
          resolveNextLearnerActivity({
            activities: [
              first,
              second
            ],
            completedActivityIds: [
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
          "second"
        );
      }
    );


    it(
      "does not let diversity override materially greater learning need",
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

        expect(
          resolveNextLearnerActivity({
            activities: [
              first,
              second
            ],
            completedActivityIds: [
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
                  0.1,
                observationCount:
                  2,
                level:
                  "exploring"
              },
              {
                skillId:
                  "skill-b",
                masteryScore:
                  0.6,
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
      "keeps catalogue sequence when previous activity is not a candidate",
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

        expect(
          selectRemediationActivity({
            activities: [
              first,
              second
            ],
            lastCompletedActivityId:
              "outside-catalogue",
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
      "keeps unfinished eligible learning ahead of anti-repetition",
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

        expect(
          resolveNextLearnerActivity({
            activities: [
              first,
              second
            ],
            completedActivityIds: [
              "first"
            ],
            lastCompletedActivityId:
              "first",
            skillProgress: [
              {
                skillId:
                  "skill-a",
                masteryScore:
                  0.1,
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
                  2,
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
'@

    $tests = $tests.Substring(0,$lastIndex) + $newTests + $tests.Substring($lastIndex)
    WriteText $resolverTestPath $tests
}

Write-Host "PASS: anti-repetition implementation installed after learning-need comparison" -ForegroundColor Green
Write-Host "PASS: unfinished-first progression remains unchanged" -ForegroundColor Green
Write-Host "PASS: no randomisation or persistence migration introduced" -ForegroundColor Green

Invoke-NativeStep "Activity diversity resolver tests" "pnpm --filter learner-web exec vitest run src/journey/nextLearnerActivity.service.test.ts"
Invoke-NativeStep "Learner selector tests" "pnpm --filter learner-web exec vitest run src/features/play/selectLearnerActivity.test.ts"
Invoke-NativeStep "Learner web typecheck" "pnpm --filter learner-web typecheck"
Invoke-NativeStep "Learner web tests" "pnpm --filter learner-web test"
Invoke-NativeStep "Mastery validation" "pnpm mastery:validate"
Invoke-NativeStep "Content sequencing validation" "pnpm content:sequence:validate"
Invoke-NativeStep "Content eligibility validation" "pnpm content:eligibility:validate"
Invoke-NativeStep "Curriculum validation" "pnpm curriculum:validate"
Invoke-NativeStep "Repository typecheck" "pnpm typecheck"
Invoke-NativeStep "All tests" "pnpm test"
Invoke-NativeStep "Production build" "pnpm build"
Invoke-NativeStep "Storybook production build" "pnpm storybook:build"
Invoke-NativeStep "Learner journey regression" "pnpm qa:journey"
Invoke-NativeStep "Accessibility regression" "pnpm qa:a11y"
Invoke-NativeStep "Visual regression" "pnpm qa:visual"
Invoke-NativeStep "Content compiler reproducibility" "pnpm content:check"
Invoke-NativeStep "Frozen lockfile verification" "pnpm install --frozen-lockfile"
Invoke-NativeStep "Git whitespace check" "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008P: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Immediate remediation repetition is avoided when learning need is equivalent." -ForegroundColor Cyan
Write-Host "Materially greater learning need still overrides diversity." -ForegroundColor Cyan
Write-Host "Unfinished eligible learning remains first priority." -ForegroundColor Cyan
Write-Host "Catalogue sequence and ID remain deterministic fallbacks." -ForegroundColor Cyan
Write-Host "No randomisation, history window, schema, persistence, manifest, dependency, or lockfile migration was introduced." -ForegroundColor Cyan
Write-Host "Log: $log" -ForegroundColor White
