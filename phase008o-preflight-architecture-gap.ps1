Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008o-architecture-gap-contract-$stamp.txt"

function Add-Line([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
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
        throw "Safety assertion failed: dependency/generated files entered Phase 008O scope."
    }
}

trap {
    Add-Line ""
    Add-Line "PHASE 008O PREFLIGHT: FAILED"
    Add-Line ($_ | Out-String)
    Add-Line $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008O PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008O PREFLIGHT" -ForegroundColor Cyan
Write-Host "Post-Remediation Architecture Gap Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Add-Line "HIBEYA AKAL BUDI - PHASE 008O PREFLIGHT"
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

$parentFiles = @(
    Get-SourceFiles `
        (Join-Path $root "apps\parent-web\src") `
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

$domainFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\domain\src") `
        @("*.ts","*.tsx","*.json")
)

$curriculumSchemaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\curriculum-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$contentSchemaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\content-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$gameRuntimeFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\game-runtime\src") `
        @("*.ts","*.tsx","*.json")
)

$uiFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\ui\src") `
        @("*.ts","*.tsx","*.json")
)

$designSystemFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\design-system\src") `
        @("*.ts","*.tsx","*.json")
)

$contentCompilerFiles = @(
    Get-SourceFiles `
        (Join-Path $root "tools\content-compiler") `
        @("*.ts","*.mjs","*.cjs","*.json")
)

$curriculumToolFiles = @(
    Get-SourceFiles `
        (Join-Path $root "tools\curriculum") `
        @("*.ts","*.mjs","*.cjs","*.json")
)

$qaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "tools\visual-regression\tests") `
        @("*.ts","*.tsx")
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

$curriculumContentFiles = @(
    Get-SourceFiles `
        (Join-Path $root "content\curriculum") `
        @("*.json","*.ts","*.tsx")
)

$allFiles = @(
    @($learnerFiles) +
    @($parentFiles) +
    @($contentLibraryFiles) +
    @($learningInsightFiles) +
    @($offlineFiles) +
    @($domainFiles) +
    @($curriculumSchemaFiles) +
    @($contentSchemaFiles) +
    @($gameRuntimeFiles) +
    @($uiFiles) +
    @($designSystemFiles) +
    @($contentCompilerFiles) +
    @($curriculumToolFiles) +
    @($qaFiles) +
    @($manifestFiles) +
    @($curriculumContentFiles)
)

Assert-NoForbiddenFiles $allFiles

$scopeCounts = [PSCustomObject]@{
    LearnerWeb        = @($learnerFiles).Count
    ParentWeb         = @($parentFiles).Count
    ContentLibrary    = @($contentLibraryFiles).Count
    LearningInsights  = @($learningInsightFiles).Count
    Offline           = @($offlineFiles).Count
    Domain            = @($domainFiles).Count
    CurriculumSchema  = @($curriculumSchemaFiles).Count
    ContentSchema     = @($contentSchemaFiles).Count
    GameRuntime       = @($gameRuntimeFiles).Count
    UI                = @($uiFiles).Count
    DesignSystem      = @($designSystemFiles).Count
    ContentCompiler   = @($contentCompilerFiles).Count
    CurriculumTools   = @($curriculumToolFiles).Count
    JourneyQA         = @($qaFiles).Count
    ActivityManifests = @($manifestFiles).Count
    CurriculumContent = @($curriculumContentFiles).Count
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
    "packages\learning-insights\src\analyse.ts",
    "packages\content-library\src\eligibility.ts",
    "packages\content-library\src\catalogue.ts",
    "packages\offline\src\skillMastery.repository.ts",
    "packages\offline\src\learningJourney.repository.ts",
    "content\curriculum\skill-graph.json",
    "tools\content-compiler\compile.mjs",
    "package.json"
)

foreach ($target in $targets) {
    Add-FileSnapshot $target
}

Write-Host "Inspecting confidence and evidence sufficiency..." -ForegroundColor Cyan

Search-Files `
    @(
        @($learnerFiles) +
        @($learningInsightFiles) +
        @($offlineFiles) +
        @($contentLibraryFiles)
    ) `
    @(
        "confidence",
        "minimumObservations",
        "observationCount",
        "masteryScoreThreshold",
        "masteryScore",
        "unobserved",
        "exploring",
        "developing",
        "mastered",
        "lastObservedAt",
        "processedSessionIds"
    ) `
    "CANDIDATE A - MASTERY CONFIDENCE / EVIDENCE SUFFICIENCY"

Write-Host "Inspecting repetition and activity-diversity controls..." -ForegroundColor Cyan

Search-Files `
    @(
        @($learnerFiles) +
        @($contentLibraryFiles) +
        @($offlineFiles) +
        @($manifestFiles)
    ) `
    @(
        "lastCompletedActivityId",
        "completedActivityIds",
        "lastActivity",
        "recentActivity",
        "history",
        "repeat",
        "replay",
        "retry",
        "diversity",
        "variety",
        "cooldown",
        "avoid",
        "sequence",
        "selectRemediationActivity"
    ) `
    "CANDIDATE B - ACTIVITY DIVERSITY / ANTI-REPETITION"

Write-Host "Inspecting difficulty progression..." -ForegroundColor Cyan

Search-Files `
    @(
        @($manifestFiles) +
        @($contentLibraryFiles) +
        @($contentCompilerFiles) +
        @($curriculumSchemaFiles) +
        @($learnerFiles)
    ) `
    @(
        "difficulty",
        "difficultyLevel",
        "level",
        "challenge",
        "scaffold",
        "progression",
        "sequence",
        "ageBands",
        "estimatedSeconds"
    ) `
    "CANDIDATE C - DIFFICULTY PROGRESSION"

Write-Host "Inspecting curriculum coverage..." -ForegroundColor Cyan

Search-Files `
    @(
        @($manifestFiles) +
        @($curriculumContentFiles) +
        @($curriculumSchemaFiles) +
        @($curriculumToolFiles) +
        @($contentLibraryFiles)
    ) `
    @(
        "skillMappings",
        "primary",
        "supporting",
        "curriculumMappings",
        "coverage",
        "strand",
        "domain",
        "objective",
        "objectives",
        "ageBands",
        "prerequisite",
        "sequence"
    ) `
    "CANDIDATE D - CURRICULUM COVERAGE / CONTENT DEPTH"

Write-Host "Inspecting session orchestration..." -ForegroundColor Cyan

Search-Files `
    @(
        @($learnerFiles) +
        @($gameRuntimeFiles) +
        @($offlineFiles)
    ) `
    @(
        "session",
        "sessionId",
        "startSession",
        "completeLocalSession",
        "durationSeconds",
        "startedAt",
        "completedAt",
        "nextActivity",
        "queue",
        "plan",
        "daily",
        "limit",
        "break"
    ) `
    "CANDIDATE E - LEARNER SESSION ORCHESTRATION"

Write-Host "Inspecting parent insight readiness..." -ForegroundColor Cyan

Search-Files `
    @(
        @($parentFiles) +
        @($learningInsightFiles) +
        @($offlineFiles) +
        @($domainFiles)
    ) `
    @(
        "parent",
        "guardian",
        "dashboard",
        "insight",
        "summary",
        "progress",
        "mastery",
        "strength",
        "support",
        "recommendation",
        "activityMetadata",
        "completedSessionCount"
    ) `
    "CANDIDATE F - PARENT-FACING LEARNING INSIGHTS"

Write-Host "Inspecting learner UX/productisation readiness..." -ForegroundColor Cyan

Search-Files `
    @(
        @($learnerFiles) +
        @($uiFiles) +
        @($designSystemFiles) +
        @($qaFiles)
    ) `
    @(
        "home",
        "explore",
        "progress",
        "continue",
        "feedback",
        "celebration",
        "empty state",
        "loading",
        "offline",
        "accessibility",
        "touch target",
        "responsive",
        "mobile"
    ) `
    "CANDIDATE G - LEARNER UX / PRODUCTISATION"

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

        $skillCount =
            if ($null -ne $manifest.skillMappings) {
                @($manifest.skillMappings).Count
            }
            else {
                0
            }

        Add-Line (
            "ID={0} | Enabled={1} | Sequence={2} | Difficulty={3} | SkillMappings={4}" -f
            $id,
            $enabled,
            $sequence,
            $difficulty,
            $skillCount
        )
    }
    catch {
        Add-Line "MANIFEST_PARSE_ERROR: $($manifestFile.Name)"
    }
}

Add-Line ""
Add-Line "===================================================="
Add-Line "PHASE 008O DECISION INSTRUCTIONS"
Add-Line "===================================================="
Add-Line "This preflight intentionally makes no implementation changes."
Add-Line "Use the evidence above to choose exactly ONE next architecture priority."
Add-Line "Do not combine confidence, diversity, difficulty, coverage, session orchestration,"
Add-Line "parent insights, and UX productisation into one phase."
Add-Line "Prefer the earliest missing foundation that later candidates depend upon."

Write-Host ""
Write-Host "PASS: Phase 008O preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, persistence, manifest, dependency, generated catalogue, or lockfile was modified." -ForegroundColor Cyan
