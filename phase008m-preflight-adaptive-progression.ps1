Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"

New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008m-adaptive-progression-contract-$stamp.txt"

function AddLine([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
}

function AddFile([string]$RelativePath) {
    $full = Join-Path $root $RelativePath

    AddLine ""
    AddLine "===================================================="
    AddLine "FILE: $RelativePath"
    AddLine "===================================================="

    if (Test-Path $full) {
        Get-Content $full | Add-Content -Path $report -Encoding UTF8
    }
    else {
        AddLine "[MISSING]"
    }
}

function GetFiles(
    [string]$Path,
    [string[]]$Includes
) {
    if (-not (Test-Path $Path)) {
        return @()
    }

    return @(
        Get-ChildItem `
            $Path `
            -Recurse `
            -File `
            -Include $Includes `
            -ErrorAction SilentlyContinue
    )
}

function SearchFiles(
    [object[]]$Files,
    [string[]]$Patterns,
    [string]$Section
) {
    AddLine ""
    AddLine "===================================================="
    AddLine $Section
    AddLine "===================================================="

    $safeFiles = @($Files)

    if ($safeFiles.Count -eq 0) {
        AddLine "[NO FILES]"
        return
    }

    foreach ($pattern in $Patterns) {
        AddLine ""
        AddLine "---- PATTERN: $pattern ----"

        $safeFiles |
        Select-String `
            -Pattern $pattern `
            -SimpleMatch `
            -Context 2,7 `
            -ErrorAction SilentlyContinue |
        ForEach-Object {
            $_.ToString() |
                Add-Content `
                    -Path $report `
                    -Encoding UTF8
        }
    }
}

trap {
    AddLine ""
    AddLine "FAILED"
    AddLine ($_ | Out-String)
    AddLine $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008M PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008M PREFLIGHT" -ForegroundColor Cyan
Write-Host "Mastery-Aware Adaptive Progression Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

AddLine "HIBEYA AKAL BUDI - PHASE 008M PREFLIGHT"
AddLine "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
AddLine "PowerShell: $($PSVersionTable.PSVersion)"
AddLine "Node: $((& node --version).Trim())"
AddLine "pnpm: $((& pnpm --version).Trim())"

Write-Host "Collecting source-only scopes..." -ForegroundColor Cyan

$learnerFiles = @(
    GetFiles `
        (Join-Path $root "apps\learner-web\src") `
        @("*.ts","*.tsx")
)

$parentFiles = @(
    GetFiles `
        (Join-Path $root "apps\parent-web\src") `
        @("*.ts","*.tsx")
)

$contentLibraryFiles = @(
    GetFiles `
        (Join-Path $root "packages\content-library\src") `
        @("*.ts","*.tsx","*.json")
)

$learningInsightFiles = @(
    GetFiles `
        (Join-Path $root "packages\learning-insights\src") `
        @("*.ts","*.tsx","*.json")
)

$offlineFiles = @(
    GetFiles `
        (Join-Path $root "packages\offline\src") `
        @("*.ts","*.tsx")
)

$curriculumFiles = @(
    GetFiles `
        (Join-Path $root "packages\curriculum-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$domainFiles = @(
    GetFiles `
        (Join-Path $root "packages\domain\src") `
        @("*.ts","*.tsx")
)

$gameRuntimeFiles = @(
    GetFiles `
        (Join-Path $root "packages\game-runtime\src") `
        @("*.ts","*.tsx")
)

$contentCompilerFiles = @(
    GetFiles `
        (Join-Path $root "tools\content-compiler") `
        @("*.ts","*.mjs","*.cjs","*.json")
)

$manifestFiles = @()
$manifestRoot = Join-Path $root "content\activity-manifests"

if (Test-Path $manifestRoot) {
    $manifestFiles = @(
        Get-ChildItem `
            $manifestRoot `
            -File `
            -Filter *.json `
            -ErrorAction SilentlyContinue
    )
}

$curriculumContentFiles = @(
    GetFiles `
        (Join-Path $root "content\curriculum") `
        @("*.json","*.ts","*.tsx")
)

$allFiles = @(
    @($learnerFiles) +
    @($parentFiles) +
    @($contentLibraryFiles) +
    @($learningInsightFiles) +
    @($offlineFiles) +
    @($curriculumFiles) +
    @($domainFiles) +
    @($gameRuntimeFiles) +
    @($contentCompilerFiles) +
    @($manifestFiles) +
    @($curriculumContentFiles)
)

$forbidden = @(
    $allFiles |
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
    throw "Safety assertion failed: dependency/generated files entered Phase 008M scope."
}

$scopeCounts = [PSCustomObject]@{
    LearnerWeb        = @($learnerFiles).Count
    ParentWeb         = @($parentFiles).Count
    ContentLibrary    = @($contentLibraryFiles).Count
    LearningInsights  = @($learningInsightFiles).Count
    Offline           = @($offlineFiles).Count
    CurriculumSchema  = @($curriculumFiles).Count
    Domain            = @($domainFiles).Count
    GameRuntime       = @($gameRuntimeFiles).Count
    ContentCompiler   = @($contentCompilerFiles).Count
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
    "apps\learner-web\src\services\skillMasteryService.ts",
    "packages\content-library\src\eligibility.ts",
    "packages\content-library\src\catalogue.ts",
    "packages\learning-insights\src\mastery.ts",
    "packages\learning-insights\src\analyse.ts",
    "packages\learning-insights\src\index.ts",
    "packages\offline\src\skillMastery.repository.ts",
    "packages\offline\src\learningJourney.repository.ts",
    "content\curriculum\skill-graph.json",
    "tools\content-compiler\compile.mjs",
    "package.json"
)

foreach ($target in $targets) {
    AddFile $target
}

Write-Host "Inspecting progression and recommendation contracts..." -ForegroundColor Cyan

SearchFiles `
    $allFiles `
    @(
        "resolveNextLearnerActivity",
        "selectLearnerActivity",
        "getEligibleActivitiesForLearner",
        "getMasteredSkillIds",
        "masteredSkillIds",
        "completedActivityIds",
        "lastCompletedActivityId",
        "sequence",
        "difficulty",
        "recommended",
        "recommend",
        "priority",
        "rank",
        "ranking",
        "score",
        "masteryScore",
        "level",
        "remediation",
        "revision",
        "review",
        "practice",
        "repeat",
        "retry",
        "nextActivity",
        "next activity"
    ) `
    "PROGRESSION / RECOMMENDATION SEARCH"

Write-Host "Inspecting learner-support and parent-insight surfaces..." -ForegroundColor Cyan

SearchFiles `
    @(
        @($learnerFiles) +
        @($parentFiles) +
        @($learningInsightFiles) +
        @($offlineFiles)
    ) `
    @(
        "progress",
        "mastery",
        "mastered",
        "developing",
        "exploring",
        "strength",
        "needs support",
        "support",
        "insight",
        "recommendation",
        "parent",
        "guardian",
        "dashboard",
        "summary",
        "streak",
        "completedSessionCount"
    ) `
    "LEARNER / PARENT INSIGHT SEARCH"

Write-Host "Inspecting curriculum policy hooks..." -ForegroundColor Cyan

SearchFiles `
    @(
        @($curriculumFiles) +
        @($curriculumContentFiles) +
        @($manifestFiles) +
        @($contentCompilerFiles)
    ) `
    @(
        "prerequisite",
        "required",
        "recommended",
        "difficulty",
        "sequence",
        "skillMappings",
        "primary",
        "supporting",
        "weight",
        "ageBands",
        "estimatedSeconds",
        "objectives",
        "catalogue"
    ) `
    "CURRICULUM POLICY SEARCH"

Write-Host "Capturing current manifests..." -ForegroundColor Cyan

AddLine ""
AddLine "===================================================="
AddLine "CURRENT ACTIVITY MANIFESTS"
AddLine "===================================================="

foreach ($manifest in (@($manifestFiles) | Sort-Object Name)) {
    $relative = $manifest.FullName.Substring($root.Length).TrimStart("\")
    AddFile $relative
}

Write-Host ""
Write-Host "PASS: Phase 008M preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, persistence, manifest, generated catalogue, dependency, or lock files were modified." -ForegroundColor Cyan
