Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008p-activity-diversity-contract-$stamp.txt"

function Add-Line([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
}

function Add-FileSnapshot([string]$RelativePath) {
    $full = Join-Path $root $RelativePath

    Add-Line ""
    Add-Line "===================================================="
    Add-Line "FILE: $RelativePath"
    Add-Line "===================================================="

    if (Test-Path $full) {
        Get-Content $full -ErrorAction Stop |
            Add-Content -Path $report -Encoding UTF8
    }
    else {
        Add-Line "[MISSING]"
    }
}

function Get-SourceFiles(
    [string]$Path,
    [string[]]$Includes
) {
    if (-not (Test-Path $Path)) {
        return @()
    }

    return @(
        Get-ChildItem `
            -Path $Path `
            -Recurse `
            -File `
            -Include $Includes `
            -ErrorAction SilentlyContinue
    )
}

function Search-Files(
    [object[]]$Files,
    [string[]]$Patterns,
    [string]$Section
) {
    Add-Line ""
    Add-Line "===================================================="
    Add-Line $Section
    Add-Line "===================================================="

    $safeFiles = @($Files)

    if ($safeFiles.Count -eq 0) {
        Add-Line "[NO FILES]"
        return
    }

    foreach ($pattern in $Patterns) {
        Add-Line ""
        Add-Line "---- PATTERN: $pattern ----"

        $matches = @(
            $safeFiles |
                Select-String `
                    -Pattern $pattern `
                    -SimpleMatch `
                    -Context 2,7 `
                    -ErrorAction SilentlyContinue
        )

        if ($matches.Count -eq 0) {
            Add-Line "[NO MATCHES]"
            continue
        }

        foreach ($match in $matches) {
            $match.ToString() |
                Add-Content `
                    -Path $report `
                    -Encoding UTF8
        }
    }
}

function Assert-NoForbiddenFiles([object[]]$Files) {
    $forbidden = @(
        @($Files) |
            Where-Object {
                $_.FullName -match '\\node_modules\\' -or
                $_.FullName -match '\\storybook-static\\' -or
                $_.FullName -match '\\dist\\' -or
                $_.FullName -match '\\test-results\\' -or
                $_.FullName -match '\\playwright-report\\' -or
                $_.FullName -match '\\\.turbo\\' -or
                $_.FullName -match '\\\.git\\'
            }
    )

    if ($forbidden.Count -gt 0) {
        throw "Safety assertion failed: dependency/generated files entered Phase 008P scope."
    }
}

trap {
    Add-Line ""
    Add-Line "PHASE 008P PREFLIGHT: FAILED"
    Add-Line ($_ | Out-String)
    Add-Line $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008P PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008P PREFLIGHT" -ForegroundColor Cyan
Write-Host "Activity Diversity + Anti-Repetition Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Add-Line "HIBEYA AKAL BUDI - PHASE 008P PREFLIGHT"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Add-Line "PowerShell: $($PSVersionTable.PSVersion)"

try {
    Add-Line "Node: $((& node --version).Trim())"
}
catch {
    Add-Line "Node: [UNAVAILABLE]"
}

try {
    Add-Line "pnpm: $((& pnpm --version).Trim())"
}
catch {
    Add-Line "pnpm: [UNAVAILABLE]"
}

Write-Host "Collecting bounded source/content scopes..." -ForegroundColor Cyan

$learnerFiles = @(
    Get-SourceFiles `
        (Join-Path $root "apps\learner-web\src") `
        @("*.ts","*.tsx","*.json")
)

$contentLibraryFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\content-library\src") `
        @("*.ts","*.tsx","*.json")
)

$learningInsightFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\learning-insights\src") `
        @("*.ts","*.tsx","*.json")
)

$offlineFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\offline\src") `
        @("*.ts","*.tsx","*.json")
)

$gameRuntimeFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\game-runtime\src") `
        @("*.ts","*.tsx","*.json")
)

$manifestFiles = @()
$manifestRoot = Join-Path $root "content\activity-manifests"

if (Test-Path $manifestRoot) {
    $manifestFiles = @(
        Get-ChildItem `
            -Path $manifestRoot `
            -File `
            -Filter *.json `
            -ErrorAction SilentlyContinue
    )
}

$qaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "tools\visual-regression\tests") `
        @("*.ts","*.tsx")
)

$allFiles = @(
    @($learnerFiles) +
    @($contentLibraryFiles) +
    @($learningInsightFiles) +
    @($offlineFiles) +
    @($gameRuntimeFiles) +
    @($manifestFiles) +
    @($qaFiles)
)

Assert-NoForbiddenFiles $allFiles

$scopeCounts = [PSCustomObject]@{
    LearnerWeb        = @($learnerFiles).Count
    ContentLibrary    = @($contentLibraryFiles).Count
    LearningInsights  = @($learningInsightFiles).Count
    Offline           = @($offlineFiles).Count
    GameRuntime       = @($gameRuntimeFiles).Count
    ActivityManifests = @($manifestFiles).Count
    JourneyQA         = @($qaFiles).Count
}

$scopeCounts | Format-Table -AutoSize
$scopeCounts | Out-String | Add-Content -Path $report -Encoding UTF8

Write-Host "PASS: source-only file set prepared ($($allFiles.Count) files)" -ForegroundColor Green
Write-Host "PASS: dependency/generated directories excluded by construction" -ForegroundColor Green

$targets = @(
    "apps\learner-web\src\journey\nextLearnerActivity.service.ts",
    "apps\learner-web\src\journey\useNextLearnerActivity.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts",
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\services\skillMasteryService.ts",
    "packages\learning-insights\src\mastery.ts",
    "packages\learning-insights\src\masteryConfidence.ts",
    "packages\offline\src\learningJourney.repository.ts",
    "packages\offline\src\skillMastery.repository.ts",
    "packages\content-library\src\catalogue.ts",
    "package.json"
)

foreach ($target in $targets) {
    Add-FileSnapshot $target
}

Write-Host "Inspecting repetition-history contracts..." -ForegroundColor Cyan

Search-Files `
    @(
        @($learnerFiles) +
        @($offlineFiles)
    ) `
    @(
        "lastCompletedActivityId",
        "completedActivityIds",
        "recentActivity",
        "recentActivities",
        "activityHistory",
        "history",
        "lastActivity",
        "previousActivity",
        "sessionId",
        "completedAt",
        "lastObservedAt",
        "processedSessionIds"
    ) `
    "REPETITION HISTORY / RECENCY SEARCH"

Write-Host "Inspecting selection and tie-break behaviour..." -ForegroundColor Cyan

Search-Files `
    @(
        @($learnerFiles) +
        @($contentLibraryFiles) +
        @($learningInsightFiles)
    ) `
    @(
        "resolveNextLearnerActivity",
        "selectRemediationActivity",
        "rankByLearningNeed",
        "getActivityLearningNeed",
        "getSequencePosition",
        "localeCompare",
        "sequence",
        "lastCompletedActivityId",
        "completedActivityIds",
        "masteryScore",
        "observationCount",
        "skillProgress"
    ) `
    "SELECTION / TIE-BREAK SEARCH"

Write-Host "Inspecting catalogue diversity metadata..." -ForegroundColor Cyan

Search-Files `
    @(
        @($manifestFiles) +
        @($contentLibraryFiles)
    ) `
    @(
        "implementationKey",
        "blueprintId",
        "mechanic",
        "skillMappings",
        "primary",
        "supporting",
        "difficulty",
        "sequence",
        "titleMs",
        "titleEn",
        "theme",
        "asset",
        "category"
    ) `
    "CATALOGUE DIVERSITY METADATA SEARCH"

Write-Host "Inspecting QA coverage for repetition..." -ForegroundColor Cyan

Search-Files `
    $qaFiles `
    @(
        "continue",
        "next",
        "repeat",
        "replay",
        "same activity",
        "activity id",
        "journey",
        "remediation",
        "mastery"
    ) `
    "JOURNEY QA / REPETITION SEARCH"

Add-Line ""
Add-Line "===================================================="
Add-Line "CURRENT ACTIVITY MANIFEST SUMMARY"
Add-Line "===================================================="

foreach ($manifestFile in (@($manifestFiles) | Sort-Object Name)) {
    try {
        $manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json

        $id =
            if ($null -ne $manifest.activity -and $manifest.activity.id) {
                $manifest.activity.id
            }
            else {
                $manifestFile.BaseName
            }

        $sequence =
            if ($null -ne $manifest.catalogue -and $null -ne $manifest.catalogue.sequence) {
                $manifest.catalogue.sequence
            }
            else {
                "[none]"
            }

        $enabled =
            if ($null -ne $manifest.catalogue -and $null -ne $manifest.catalogue.enabled) {
                $manifest.catalogue.enabled
            }
            else {
                "[none]"
            }

        $difficulty =
            if ($null -ne $manifest.activity -and $null -ne $manifest.activity.difficulty) {
                $manifest.activity.difficulty
            }
            else {
                "[none]"
            }

        $implementationKey =
            if ($null -ne $manifest.runtime -and $manifest.runtime.implementationKey) {
                $manifest.runtime.implementationKey
            }
            else {
                "[none]"
            }

        $blueprintId =
            if ($null -ne $manifest.activity -and $manifest.activity.blueprintId) {
                $manifest.activity.blueprintId
            }
            else {
                "[none]"
            }

        Add-Line (
            "ID={0} | Enabled={1} | Sequence={2} | Difficulty={3} | Blueprint={4} | Implementation={5}" -f
            $id,
            $enabled,
            $sequence,
            $difficulty,
            $blueprintId,
            $implementationKey
        )
    }
    catch {
        Add-Line "MANIFEST_PARSE_ERROR: $($manifestFile.Name)"
    }
}

Add-Line ""
Add-Line "===================================================="
Add-Line "PHASE 008P DECISION QUESTIONS"
Add-Line "===================================================="
Add-Line "1. Is there enough persisted activity recency/history to avoid immediate repetition?"
Add-Line "2. Can anti-repetition be implemented without a schema migration?"
Add-Line "3. Should diversity apply only when candidates are otherwise equivalent, or influence need ranking?"
Add-Line "4. Is lastCompletedActivityId sufficient, or is a bounded recent-activity window required?"
Add-Line "5. Can the policy remain deterministic and curriculum-safe?"
Add-Line "6. Do not introduce randomisation unless the existing architecture explicitly requires it."
Add-Line "7. Do not weaken prerequisite, mastery, unfinished-first, or remediation rules."

Write-Host ""
Write-Host "PASS: Phase 008P preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, persistence, manifest, dependency, generated catalogue, or lockfile was modified." -ForegroundColor Cyan
