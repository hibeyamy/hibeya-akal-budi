Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008j-content-sequencing-contract-v3-$stamp.txt"

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

    $items = @(
        Get-ChildItem `
            $Path `
            -Recurse `
            -File `
            -Include $Includes `
            -ErrorAction SilentlyContinue
    )

    return ,$items
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
            -Context 2,6 `
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
    Write-Host "PHASE 008J PREFLIGHT V3: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008J PREFLIGHT V3" -ForegroundColor Cyan
Write-Host "Source-only Content Sequencing Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

AddLine "HIBEYA AKAL BUDI - PHASE 008J PREFLIGHT V3"
AddLine "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
AddLine "PowerShell: $($PSVersionTable.PSVersion)"
AddLine "Node: $((& node --version).Trim())"
AddLine "pnpm: $((& pnpm --version).Trim())"

Write-Host "Collecting source-only scopes..." -ForegroundColor Cyan

# IMPORTANT:
# Only source/config/content directories are traversed.
# package roots are never recursively scanned, so node_modules cannot enter the set.
$learnerFiles = @(
    GetFiles `
        (Join-Path $root "apps\learner-web\src") `
        @("*.ts","*.tsx")
)

$contentLibraryFiles = @(
    GetFiles `
        (Join-Path $root "packages\content-library\src") `
        @("*.ts","*.tsx","*.json")
)

$contentSchemaFiles = @(
    GetFiles `
        (Join-Path $root "packages\content-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$curriculumSchemaFiles = @(
    GetFiles `
        (Join-Path $root "packages\curriculum-schema\src") `
        @("*.ts","*.tsx","*.json")
)

$contentCompilerFiles = @(
    GetFiles `
        (Join-Path $root "tools\content-compiler") `
        @("*.ts","*.mjs","*.cjs","*.json")
)

$curriculumToolFiles = @(
    GetFiles `
        (Join-Path $root "tools\curriculum") `
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

$scopeCounts = [PSCustomObject]@{
    LearnerSource      = @($learnerFiles).Count
    ContentLibrary     = @($contentLibraryFiles).Count
    ContentSchema      = @($contentSchemaFiles).Count
    CurriculumSchema   = @($curriculumSchemaFiles).Count
    ContentCompiler    = @($contentCompilerFiles).Count
    CurriculumTools    = @($curriculumToolFiles).Count
    ActivityManifests  = @($manifestFiles).Count
    CurriculumContent  = @($curriculumContentFiles).Count
}

$scopeCounts | Format-Table -AutoSize
$scopeCounts | Out-String | Add-Content -Path $report -Encoding UTF8

$allFiles = @(
    @($learnerFiles) +
    @($contentLibraryFiles) +
    @($contentSchemaFiles) +
    @($curriculumSchemaFiles) +
    @($contentCompilerFiles) +
    @($curriculumToolFiles) +
    @($manifestFiles) +
    @($curriculumContentFiles)
)

# Hard safety assertion: dependency/generated trees must never appear.
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
    throw "Safety assertion failed: dependency/generated files entered the preflight scope."
}

Write-Host "PASS: source-only file set prepared ($($allFiles.Count) files)" -ForegroundColor Green
Write-Host "PASS: dependency/generated directories excluded by construction" -ForegroundColor Green

$targets = @(
    "apps\learner-web\src\journey\nextLearnerActivity.service.ts",
    "apps\learner-web\src\journey\nextLearnerActivity.service.test.ts",
    "apps\learner-web\src\journey\useNextLearnerActivity.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.test.ts",
    "packages\content-library\src\catalogue.ts",
    "packages\content-library\src\validateCatalogue.ts",
    "packages\content-library\src\index.ts",
    "packages\content-schema\src\activity.schema.ts",
    "packages\content-schema\src\index.ts",
    "packages\curriculum-schema\src\index.ts",
    "tools\content-compiler\compile.mjs",
    "package.json"
)

foreach ($target in $targets) {
    AddFile $target
}

Write-Host "Inspecting sequencing/order metadata..." -ForegroundColor Cyan

SearchFiles `
    $allFiles `
    @(
        '"sequence"',
        "sequence:",
        '"order"',
        "order:",
        '"sortOrder"',
        "sortOrder:",
        '"prerequisites"',
        "prerequisites:",
        '"dependsOn"',
        "dependsOn:",
        '"enabled"',
        "enabled:",
        '"status"',
        "status:",
        "getPlayableActivitiesForAgeBand",
        "playableActivities",
        ".sort(",
        "localeCompare",
        "difficulty",
        "malaysiaElements"
    ) `
    "SEQUENCING / ORDER / PREREQUISITE SEARCH"

Write-Host "Inspecting schemas and validators..." -ForegroundColor Cyan

$schemaFiles = @(
    @($contentSchemaFiles) +
    @($curriculumSchemaFiles) +
    @($contentLibraryFiles) +
    @($contentCompilerFiles) +
    @($curriculumToolFiles)
)

SearchFiles `
    $schemaFiles `
    @(
        "z.object",
        "safeParse",
        "validate",
        "manifest",
        "activityId",
        "ageBand",
        "difficulty",
        "sequence",
        "prerequisites"
    ) `
    "SCHEMA / VALIDATOR SEARCH"

Write-Host "Inspecting compiler/catalogue flow..." -ForegroundColor Cyan

$compilerFiles = @(
    @($contentLibraryFiles) +
    @($contentCompilerFiles) +
    @($curriculumToolFiles)
)

SearchFiles `
    $compilerFiles `
    @(
        "writeFile",
        "generated",
        "manifest",
        "activities",
        "sort",
        "order",
        "sequence",
        "index.ts"
    ) `
    "COMPILER / CATALOGUE FLOW SEARCH"

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
Write-Host "PASS: Phase 008J preflight V3 report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, manifest, generated catalogue, dependency, or lock files were modified." -ForegroundColor Cyan
