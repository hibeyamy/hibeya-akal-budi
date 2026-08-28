Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008l-skill-mastery-evidence-contract-$stamp.txt"

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
    Write-Host "PHASE 008L PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008L PREFLIGHT" -ForegroundColor Cyan
Write-Host "Skill Mastery + Learning Evidence Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

AddLine "HIBEYA AKAL BUDI - PHASE 008L PREFLIGHT"
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

$offlineFiles = @(
    GetFiles `
        (Join-Path $root "packages\offline\src") `
        @("*.ts","*.tsx")
)

$learningInsightFiles = @(
    GetFiles `
        (Join-Path $root "packages\learning-insights\src") `
        @("*.ts","*.tsx","*.json")
)

$gameRuntimeFiles = @(
    GetFiles `
        (Join-Path $root "packages\game-runtime\src") `
        @("*.ts","*.tsx")
)

$gameMechanicFiles = @(
    GetFiles `
        (Join-Path $root "packages\game-mechanics\src") `
        @("*.ts","*.tsx")
)

$contentLibraryFiles = @(
    GetFiles `
        (Join-Path $root "packages\content-library\src") `
        @("*.ts","*.tsx","*.json")
)

$curriculumFiles = @(
    GetFiles `
        (Join-Path $root "packages\curriculum-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$contentCompilerFiles = @(
    GetFiles `
        (Join-Path $root "tools\content-compiler") `
        @("*.ts","*.mjs","*.cjs","*.json")
)

$journeyQaFiles = @(
    GetFiles `
        (Join-Path $root "tools\visual-regression\tests") `
        @("*.ts","*.tsx")
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

$allFiles = @(
    @($learnerFiles) +
    @($offlineFiles) +
    @($learningInsightFiles) +
    @($gameRuntimeFiles) +
    @($gameMechanicFiles) +
    @($contentLibraryFiles) +
    @($curriculumFiles) +
    @($contentCompilerFiles) +
    @($journeyQaFiles) +
    @($manifestFiles)
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
    throw "Safety assertion failed: dependency/generated files entered Phase 008L scope."
}

Write-Host "PASS: source-only file set prepared ($($allFiles.Count) files)" -ForegroundColor Green
Write-Host "PASS: dependency/generated directories excluded by construction" -ForegroundColor Green

$scopeCounts = [PSCustomObject]@{
    LearnerWeb        = @($learnerFiles).Count
    Offline           = @($offlineFiles).Count
    LearningInsights  = @($learningInsightFiles).Count
    GameRuntime       = @($gameRuntimeFiles).Count
    GameMechanics     = @($gameMechanicFiles).Count
    ContentLibrary    = @($contentLibraryFiles).Count
    CurriculumSchema  = @($curriculumFiles).Count
    ContentCompiler   = @($contentCompilerFiles).Count
    JourneyQA         = @($journeyQaFiles).Count
    ActivityManifests = @($manifestFiles).Count
}

$scopeCounts | Format-Table -AutoSize
$scopeCounts | Out-String | Add-Content -Path $report -Encoding UTF8

$targets = @(
    "apps\learner-web\src\journey\useLearnerProgress.ts",
    "apps\learner-web\src\journey\learnerProgress.ts",
    "apps\learner-web\src\journey\useNextLearnerActivity.ts",
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\features\play\ActivityPlayerAdapter.tsx",
    "packages\offline\src\learningJourney.repository.ts",
    "packages\learning-insights\src\types.ts",
    "packages\learning-insights\src\index.ts",
    "packages\learning-insights\src\activityMetadata.ts",
    "packages\game-runtime\src\index.ts",
    "packages\game-mechanics\src\index.ts",
    "packages\content-library\src\eligibility.ts",
    "packages\content-library\src\catalogue.ts",
    "packages\curriculum-schema\src\index.ts",
    "tools\content-compiler\compile.mjs",
    "content\curriculum\skill-graph.json",
    "package.json"
)

foreach ($target in $targets) {
    AddFile $target
}

Write-Host "Inspecting completion, result and mastery contracts..." -ForegroundColor Cyan

SearchFiles `
    $allFiles `
    @(
        "completedActivityIds",
        "completedSessionCount",
        "recordCompletedJourneyActivity",
        "onComplete",
        "completeActivity",
        "completion",
        "result",
        "score",
        "correct",
        "incorrect",
        "attempt",
        "attempts",
        "success",
        "accuracy",
        "mastery",
        "mastered",
        "proficiency",
        "evidence",
        "learningEvidence",
        "skillId",
        "skillIds",
        "skillMappings",
        "weight",
        "primary",
        "supporting"
    ) `
    "COMPLETION / RESULT / MASTERY SEARCH"

Write-Host "Inspecting runtime event and persistence boundaries..." -ForegroundColor Cyan

SearchFiles `
    @(
        @($learnerFiles) +
        @($offlineFiles) +
        @($gameRuntimeFiles) +
        @($gameMechanicFiles)
    ) `
    @(
        "dispatch",
        "event",
        "emit",
        "callback",
        "onCorrect",
        "onIncorrect",
        "onAnswer",
        "onResult",
        "onFinish",
        "onComplete",
        "IndexedDB",
        "getDatabase",
        "db.put",
        "db.get",
        "settings",
        "repository"
    ) `
    "RUNTIME EVENT / PERSISTENCE SEARCH"

Write-Host "Inspecting learning-insights and skill-weight semantics..." -ForegroundColor Cyan

SearchFiles `
    @(
        @($learningInsightFiles) +
        @($curriculumFiles) +
        @($manifestFiles) +
        @($contentCompilerFiles)
    ) `
    @(
        "ActivityLearningMetadata",
        "objectives",
        "skillMappings",
        "role",
        "weight",
        "strength",
        "required",
        "recommended",
        "estimatedSeconds",
        "difficulty",
        "learningInsights",
        "activityMetadata"
    ) `
    "LEARNING INSIGHTS / SKILL WEIGHT SEARCH"

Write-Host "Capturing current activity manifests..." -ForegroundColor Cyan

AddLine ""
AddLine "===================================================="
AddLine "CURRENT ACTIVITY MANIFESTS"
AddLine "===================================================="

foreach ($manifest in (@($manifestFiles) | Sort-Object Name)) {
    $relative = $manifest.FullName.Substring($root.Length).TrimStart("\")
    AddFile $relative
}

Write-Host ""
Write-Host "PASS: Phase 008L preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, persistence, manifest, generated catalogue, dependency, or lock files were modified." -ForegroundColor Cyan
