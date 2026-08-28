Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008q-difficulty-progression-contract-$stamp.txt"

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
                    -Context 2,8 `
                    -ErrorAction SilentlyContinue
        )

        if ($matches.Count -eq 0) {
            Add-Line "[NO MATCHES]"
            continue
        }

        foreach ($match in $matches) {
            $match.ToString() |
                Add-Content -Path $report -Encoding UTF8
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
        throw "Safety assertion failed: dependency/generated files entered Phase 008Q scope."
    }
}

trap {
    Add-Line ""
    Add-Line "PHASE 008Q PREFLIGHT: FAILED"
    Add-Line ($_ | Out-String)
    Add-Line $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008Q PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008Q PREFLIGHT" -ForegroundColor Cyan
Write-Host "Difficulty Progression Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Add-Line "HIBEYA AKAL BUDI - PHASE 008Q PREFLIGHT"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Add-Line "PowerShell: $($PSVersionTable.PSVersion)"

try { Add-Line "Node: $((& node --version).Trim())" }
catch { Add-Line "Node: [UNAVAILABLE]" }

try { Add-Line "pnpm: $((& pnpm --version).Trim())" }
catch { Add-Line "pnpm: [UNAVAILABLE]" }

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

$contentSchemaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\content-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$curriculumSchemaFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\curriculum-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$learningInsightFiles = @(
    Get-SourceFiles `
        (Join-Path $root "packages\learning-insights\src") `
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
    @($contentLibraryFiles) +
    @($contentSchemaFiles) +
    @($curriculumSchemaFiles) +
    @($learningInsightFiles) +
    @($contentCompilerFiles) +
    @($curriculumToolFiles) +
    @($manifestFiles) +
    @($curriculumContentFiles)
)

Assert-NoForbiddenFiles $allFiles

$scopeCounts = [PSCustomObject]@{
    LearnerWeb        = @($learnerFiles).Count
    ContentLibrary    = @($contentLibraryFiles).Count
    ContentSchema     = @($contentSchemaFiles).Count
    CurriculumSchema  = @($curriculumSchemaFiles).Count
    LearningInsights  = @($learningInsightFiles).Count
    ContentCompiler   = @($contentCompilerFiles).Count
    CurriculumTools   = @($curriculumToolFiles).Count
    ActivityManifests = @($manifestFiles).Count
    CurriculumContent = @($curriculumContentFiles).Count
}

$scopeCounts | Format-Table -AutoSize
$scopeCounts | Out-String | Add-Content -Path $report -Encoding UTF8

Write-Host "PASS: source-only file set prepared ($($allFiles.Count) files)" -ForegroundColor Green
Write-Host "PASS: dependency/generated directories excluded by construction" -ForegroundColor Green

$targets = @(
    "apps\learner-web\src\journey\nextLearnerActivity.service.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts",
    "packages\content-library\src\catalogue.ts",
    "packages\content-library\src\eligibility.ts",
    "packages\learning-insights\src\mastery.ts",
    "packages\learning-insights\src\masteryConfidence.ts",
    "packages\content-schema\src\index.ts",
    "packages\curriculum-schema\src\index.ts",
    "content\curriculum\skill-graph.json",
    "tools\content-compiler\compile.mjs",
    "package.json"
)

foreach ($target in $targets) {
    Add-FileSnapshot $target
}

Write-Host "Inspecting difficulty metadata contracts..." -ForegroundColor Cyan

Search-Files `
    @(
        @($manifestFiles) +
        @($contentSchemaFiles) +
        @($contentLibraryFiles) +
        @($contentCompilerFiles)
    ) `
    @(
        "difficulty",
        "difficultyLevel",
        "challenge",
        "level",
        "sequence",
        "estimatedSeconds",
        "implementationKey",
        "blueprintId"
    ) `
    "DIFFICULTY METADATA / COMPILER SEARCH"

Write-Host "Inspecting adaptive progression hooks..." -ForegroundColor Cyan

Search-Files `
    @(
        @($learnerFiles) +
        @($learningInsightFiles) +
        @($contentLibraryFiles)
    ) `
    @(
        "getActivityLearningNeed",
        "rankByLearningNeed",
        "resolveNextLearnerActivity",
        "selectRemediationActivity",
        "masteryScore",
        "observationCount",
        "getEvidenceAdjustedLearningNeed",
        "sequence",
        "difficulty",
        "lastCompletedActivityId",
        "avoidActivityId"
    ) `
    "ADAPTIVE PROGRESSION / DIFFICULTY HOOK SEARCH"

Write-Host "Inspecting curriculum progression semantics..." -ForegroundColor Cyan

Search-Files `
    @(
        @($curriculumSchemaFiles) +
        @($curriculumContentFiles) +
        @($curriculumToolFiles) +
        @($manifestFiles)
    ) `
    @(
        "prerequisite",
        "sequence",
        "progression",
        "difficulty",
        "scaffold",
        "strand",
        "domain",
        "skillMappings",
        "primary",
        "supporting",
        "ageBands"
    ) `
    "CURRICULUM PROGRESSION SEARCH"

Add-Line ""
Add-Line "===================================================="
Add-Line "CURRENT ACTIVITY DIFFICULTY SUMMARY"
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

        $difficulty =
            if ($null -ne $manifest.activity -and $null -ne $manifest.activity.difficulty) {
                $manifest.activity.difficulty
            }
            elseif ($null -ne $manifest.difficulty) {
                $manifest.difficulty
            }
            else {
                "[none]"
            }

        $sequence =
            if ($null -ne $manifest.catalogue -and $null -ne $manifest.catalogue.sequence) {
                $manifest.catalogue.sequence
            }
            else {
                "[none]"
            }

        $ageBands =
            if ($null -ne $manifest.activity -and $null -ne $manifest.activity.ageBands) {
                (@($manifest.activity.ageBands) -join ",")
            }
            elseif ($null -ne $manifest.ageBands) {
                (@($manifest.ageBands) -join ",")
            }
            else {
                "[none]"
            }

        Add-Line (
            "ID={0} | Difficulty={1} | Sequence={2} | AgeBands={3}" -f
            $id,
            $difficulty,
            $sequence,
            $ageBands
        )
    }
    catch {
        Add-Line "MANIFEST_PARSE_ERROR: $($manifestFile.Name)"
    }
}

Add-Line ""
Add-Line "===================================================="
Add-Line "PHASE 008Q DECISION QUESTIONS"
Add-Line "===================================================="
Add-Line "1. Is difficulty represented in source manifests with a stable numeric/ordinal contract?"
Add-Line "2. Does the compiler currently emit difficulty into ResolvedPlayableActivity?"
Add-Line "3. Is there enough catalogue diversity across difficulty values to validate adaptive difficulty today?"
Add-Line "4. Should difficulty be a hard eligibility gate, a soft rank factor, or sequence metadata only?"
Add-Line "5. Can difficulty adaptation be based on existing mastery confidence without inventing a second learner model?"
Add-Line "6. Must progression preserve prerequisites, unfinished-first ordering, remediation, and anti-repetition?"
Add-Line "7. Do not implement difficulty adaptation if the catalogue has insufficient difficulty variance."

Write-Host ""
Write-Host "PASS: Phase 008Q preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, persistence, manifest, dependency, generated catalogue, or lockfile was modified." -ForegroundColor Cyan
