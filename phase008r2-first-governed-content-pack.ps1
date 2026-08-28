Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008r2-first-governed-content-pack-$stamp.log"

$compiler = Join-Path $root "tools\content-compiler\compile.mjs"
$manifest = Join-Path $root "content\activity-manifests\beza-bunga-raya-001.json"

function Log([string]$Text = "") {
    Add-Content -Path $log -Value $Text -Encoding UTF8
}

function Backup([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    $relative = $Path.Substring($root.Length).TrimStart("\")
    $safe = $relative -replace '[\\/:*?"<>|]', '_'
    Copy-Item $Path (Join-Path $backups "$stamp-$safe") -Force
}

function WriteUtf8([string]$Path,[string]$Content) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    [IO.File]::WriteAllText(
        $Path,
        $Content.TrimEnd() + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Native([string]$Name,[string]$Command) {
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    Write-Host $Command
    Log ""
    Log "==> $Name"
    Log $Command

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & "$env:ComSpec" /d /c $Command 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $old
    }

    foreach ($item in $output) {
        $text =
            if ($item -is [System.Management.Automation.ErrorRecord]) {
                $item.Exception.Message
            }
            else {
                [string]$item
            }

        Write-Host $text
        Log $text
    }

    if ($code -ne 0) {
        throw "$Name failed with exit code $code"
    }

    Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
    Log ""
    Log "PHASE 008R2: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008R2: FAILED" -ForegroundColor Red
    Write-Host "Log: $log" -ForegroundColor Yellow
    Write-Host "Do not make manual source edits until the failure log is reviewed." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R2" -ForegroundColor Cyan
Write-Host "First Governed Content Pack + Draft Lifecycle" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $compiler)) {
    throw "Compiler not found: $compiler"
}

$compilerText = Get-Content $compiler -Raw

foreach ($token in @(
    "function validateManifest(",
    "activity.provenance.originalityReviewed ===",
    "const manifests =",
    "validateManifest(",
    "return {",
    "filename,",
    "manifest"
)) {
    if ($compilerText -notmatch [Regex]::Escape($token)) {
        throw "Compiler contract drifted. Missing token: $token"
    }
}

Write-Host "PASS: exact compiler contract verified" -ForegroundColor Green

# ------------------------------------------------------------------
# Fix the draft lifecycle discovered by the 008R2 preflight.
#
# Current authoring tool intentionally creates:
#   catalogue.enabled=false
#   metadata.active=false
#   originalityReviewed=false
#
# But compile.mjs currently requires originalityReviewed=true for every
# manifest. This makes a safely generated draft uncompilable.
#
# Production compilation will now:
#   - recognise the exact safe-draft state,
#   - perform lightweight draft guardrail checks,
#   - exclude drafts from generated runtime/catalogue outputs,
#   - continue applying the full existing validation to production content.
# ------------------------------------------------------------------

Backup $compiler

$anchor = @'
function validateManifest(
  manifest,
  filename
) {
'@

$insert = @'
function isSafeDraftManifest(
  manifest
) {
  return (
    manifest &&
    typeof manifest ===
      "object" &&
    manifest.catalogue?.enabled ===
      false &&
    manifest.activity?.metadata?.active ===
      false &&
    manifest.activity?.provenance?.originalityReviewed ===
      false
  );
}


function validateDraftManifest(
  manifest,
  filename
) {
  assert(
    manifest &&
    typeof manifest ===
      "object",
    `${filename}: draft manifest must be an object`
  );

  assertString(
    manifest.exportName,
    `${filename}.exportName`
  );

  assertString(
    manifest.activity?.id,
    `${filename}.activity.id`
  );

  assert(
    manifest.catalogue?.enabled ===
      false,
    `${filename}: draft catalogue must remain disabled`
  );

  assert(
    manifest.activity?.metadata?.active ===
      false,
    `${filename}: draft activity metadata must remain inactive`
  );

  assert(
    manifest.activity?.provenance?.creator ===
      "HIBEYA" &&
    manifest.activity?.provenance?.originalityReviewed ===
      false,
    `${filename}: draft provenance must remain pending HIBEYA originality review`
  );

  assert(
    manifest.activity?.wellbeing?.usesCountdownPressure ===
      false &&
    manifest.activity?.wellbeing?.usesLossAversion ===
      false &&
    manifest.activity?.wellbeing?.usesStreakPressure ===
      false &&
    manifest.activity?.wellbeing?.usesInfinitePlay ===
      false &&
    manifest.activity?.wellbeing?.usesBehaviouralAds ===
      false,
    `${filename}: draft wellbeing guardrails must remain disabled`
  );

  assert(
    Array.isArray(
      manifest.skillMappings
    ) &&
    manifest.skillMappings.some(
      mapping =>
        mapping.role ===
          "primary"
    ),
    `${filename}: draft must declare at least one primary skill mapping`
  );
}


function validateManifest(
  manifest,
  filename
) {
'@

if (-not $compilerText.Contains($anchor)) {
    throw "Compiler validation anchor not found."
}

$compilerText = $compilerText.Replace($anchor,$insert)

$oldMap = @'
const manifests =
  manifestFiles.map(
    filename => {
      const fullPath =
        path.join(
          manifestRoot,
          filename
        );

      const manifest =
        readJson(
          fullPath
        );

      validateManifest(
        manifest,
        filename
      );

      return {
        filename,
        manifest
      };
    }
  );
'@

$newMap = @'
const allManifests =
  manifestFiles.map(
    filename => {
      const fullPath =
        path.join(
          manifestRoot,
          filename
        );

      const manifest =
        readJson(
          fullPath
        );

      if (
        isSafeDraftManifest(
          manifest
        )
      ) {
        validateDraftManifest(
          manifest,
          filename
        );

        return {
          filename,
          manifest,
          draft:
            true
        };
      }

      validateManifest(
        manifest,
        filename
      );

      return {
        filename,
        manifest,
        draft:
          false
      };
    }
  );


const manifests =
  allManifests.filter(
    item =>
      !item.draft
  );


const draftManifests =
  allManifests.filter(
    item =>
      item.draft
  );


for (
  const {
    filename
  } of draftManifests
) {
  console.log(
    `DRAFT SKIPPED: ${filename}`
  );
}
'@

if (-not $compilerText.Contains($oldMap)) {
    throw "Compiler manifest-loading anchor not found."
}

$compilerText = $compilerText.Replace($oldMap,$newMap)

# Duplicate IDs/export names must be checked across production AND drafts.
$compilerText = $compilerText.Replace(
@'
const activityIds =
  manifests.map(
'@,
@'
const activityIds =
  allManifests.map(
'@
)

$compilerText = $compilerText.Replace(
@'
const exportNames =
  manifests.map(
'@,
@'
const exportNames =
  allManifests.map(
'@
)

# Make compiler result explicit about drafts without changing production count.
$oldFinal = @'
    `CONTENT COMPILER: ${manifests.length} manifests compiled`
'@

$newFinal = @'
    `CONTENT COMPILER: ${manifests.length} production manifests compiled; ${draftManifests.length} safe drafts skipped`
'@

if (-not $compilerText.Contains($oldFinal)) {
    throw "Compiler final-status anchor not found."
}

$compilerText = $compilerText.Replace($oldFinal,$newFinal)

WriteUtf8 $compiler $compilerText

Write-Host "PASS: compiler now has an explicit safe-draft boundary" -ForegroundColor Green
Write-Host "PASS: production validation remains strict" -ForegroundColor Green
Write-Host "PASS: drafts are excluded from runtime/catalogue generation" -ForegroundColor Green

# ------------------------------------------------------------------
# Create the first content-pack draft for the measured FAIL skill.
#
# It reuses only existing repository assets and the existing tap-choice
# implementation. It does NOT invent a new skill, mechanic, age band,
# difficulty level, curriculum mapping, or external asset.
#
# Manual review remains mandatory before activation.
# ------------------------------------------------------------------

if (Test-Path $manifest) {
    throw "Draft already exists: $manifest"
}

$draft = @'
{
  "exportName": "bezaBungaRaya001",
  "activity": {
    "id": "beza-bunga-raya-001",
    "version": 1,
    "mechanic": "tap-choice",
    "ageBand": "3-4",
    "domains": [
      "logic"
    ],
    "skills": [
      "visual-discrimination",
      "colour-recognition"
    ],
    "difficulty": 1,
    "title": {
      "ms": "Yang Mana Berbeza?",
      "en": "Which One Is Different?"
    },
    "instruction": {
      "ms": "Cari bunga raya yang berbeza",
      "en": "Find the hibiscus that is different"
    },
    "options": [
      {
        "id": "hibiscus-red-left",
        "asset": "hibiscus-red",
        "correct": false
      },
      {
        "id": "hibiscus-red-right",
        "asset": "hibiscus-red",
        "correct": false
      },
      {
        "id": "hibiscus-yellow-different",
        "asset": "hibiscus-yellow",
        "correct": true
      }
    ],
    "development": {
      "objectiveIds": [
        "visual-discrimination"
      ],
      "rationale": {
        "ms": "Aktiviti ini memberi latihan diskriminasi visual asas dengan meminta kanak-kanak mengenal satu imej yang berbeza daripada dua imej yang sama.",
        "en": "This activity practises basic visual discrimination by asking the learner to identify one image that differs from two matching images."
      },
      "interactionMode": "independent",
      "estimatedMinutes": 2,
      "parentParticipationRecommended": false,
      "offlineExtension": {
        "ms": "Susun tiga objek selamat bersama orang dewasa, dengan dua objek yang sama dan satu yang berbeza. Cari objek yang berbeza.",
        "en": "With an adult, arrange three safe objects with two alike and one different. Find the object that is different."
      },
      "researchRefs": [
        "AB-RESEARCH-EARLY-PLAY-001"
      ]
    },
    "wellbeing": {
      "sensoryLoad": "low",
      "rewardIntensity": 1,
      "animationIntensity": 0,
      "audioIntensity": 0,
      "usesCountdownPressure": false,
      "usesLossAversion": false,
      "usesStreakPressure": false,
      "usesInfinitePlay": false,
      "usesBehaviouralAds": false,
      "penalisesMistakes": false
    },
    "malaysia": {
      "relevance": "core",
      "elements": [
        "bunga raya"
      ],
      "culturalReviewRequired": true
    },
    "accessibility": {
      "reducedMotionSafe": true,
      "requiresReading": false,
      "requiresAudio": false,
      "colourIsLearningTarget": false,
      "largeTouchTargets": true,
      "alternativeInstructionAvailable": true
    },
    "provenance": {
      "type": "original",
      "creator": "HIBEYA",
      "assetSourceRefs": [],
      "originalityReviewed": false,
      "culturalReviewed": false,
      "reviewedBy": "PENDING",
      "reviewedAt": "1970-01-01T00:00:00.000Z"
    },
    "metadata": {
      "estimatedSeconds": 120,
      "active": false
    }
  },
  "catalogue": {
    "blueprintId": "warna-bunga-raya",
    "enabled": false,
    "ageBands": [
      "3-4"
    ],
    "titleMs": "Yang Mana Berbeza?",
    "titleEn": "Which One Is Different?",
    "implementationKey": "colour-choice-v1",
    "sequence": 30
  },
  "learningInsights": {
    "objectives": [
      "visual-discrimination",
      "visual-matching",
      "malaysian-context"
    ],
    "malaysiaElements": [
      "bunga raya"
    ]
  },
  "curriculumMappings": [],
  "skillMappings": [
    {
      "skillId": "visual-discrimination",
      "role": "primary",
      "weight": 1
    },
    {
      "skillId": "colour-recognition",
      "role": "supporting",
      "weight": 0.25
    }
  ]
}
'@

WriteUtf8 $manifest $draft

Write-Host "PASS: first visual-discrimination content-pack draft created" -ForegroundColor Green
Write-Host "PASS: existing hibiscus assets reused; no external asset introduced" -ForegroundColor Green
Write-Host "PASS: age 3-4 and difficulty 1 preserved; no artificial difficulty variance introduced" -ForegroundColor Green
Write-Host "PASS: draft remains disabled, inactive and unreviewed" -ForegroundColor Green

# ------------------------------------------------------------------
# Validation.
# ------------------------------------------------------------------

Native "Compile production catalogue while skipping safe draft" "node tools/content-compiler/compile.mjs"
Native "Compiler reproducibility with safe draft present" "pnpm content:check"
Native "Content sequencing validation" "pnpm content:sequence:validate"
Native "Content eligibility validation" "pnpm content:eligibility:validate"
Native "Curriculum validation" "pnpm curriculum:validate"

# Coverage should still fail the release minimum because the new content is
# intentionally a draft. But it must now report draft-primary=1 for the gap.
Write-Host ""
Write-Host "==> Coverage validator draft-awareness probe" -ForegroundColor Cyan

$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"

try {
    $coverageOutput = & "$env:ComSpec" /d /c "pnpm content:coverage:validate" 2>&1
    $coverageCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $oldPreference
}

$coverageText = @()

foreach ($item in $coverageOutput) {
    $text =
        if ($item -is [System.Management.Automation.ErrorRecord]) {
            $item.Exception.Message
        }
        else {
            [string]$item
        }

    $coverageText += $text
    Write-Host $text
    Log $text
}

if ($coverageCode -eq 0) {
    throw "Coverage unexpectedly passed before manual review and enablement."
}

$joinedCoverage = $coverageText -join "`n"

if (
    $joinedCoverage -notmatch "visual-discrimination" -or
    $joinedCoverage -notmatch "draft-primary=1"
) {
    throw "Coverage validator did not recognise the new visual-discrimination draft."
}

Write-Host "PASS: coverage validator recognises the draft without treating it as released coverage" -ForegroundColor Green

Native "Repository typecheck" "pnpm typecheck"
Native "All tests" "pnpm test"
Native "Production build" "pnpm build"
Native "Frozen lockfile verification" "pnpm install --frozen-lockfile"
Native "Git whitespace check" "git diff --check"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008R2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Safe draft lifecycle is now compiler-compatible." -ForegroundColor Cyan
Write-Host "First visual-discrimination activity exists as a governed draft." -ForegroundColor Cyan
Write-Host ""
Write-Host "MANUAL ACTION REQUIRED BEFORE 008R3:" -ForegroundColor Yellow
Write-Host "Review content\activity-manifests\beza-bunga-raya-001.json for:" -ForegroundColor Yellow
Write-Host "  1. originality and wording," -ForegroundColor Yellow
Write-Host "  2. cultural appropriateness of bunga raya usage," -ForegroundColor Yellow
Write-Host "  3. whether the two-identical / one-different interaction is suitable for age 3-4," -ForegroundColor Yellow
Write-Host "  4. whether reused hibiscus assets render clearly as three separate choices." -ForegroundColor Yellow
Write-Host ""
Write-Host "Do NOT manually toggle enabled/active/review flags yet." -ForegroundColor Yellow
Write-Host "008R3 will perform governed promotion after your review approval." -ForegroundColor Yellow
Write-Host "Log: $log" -ForegroundColor White
