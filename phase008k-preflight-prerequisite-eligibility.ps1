Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008k-prerequisite-eligibility-contract-$stamp.txt"

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
    Write-Host "PHASE 008K PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008K PREFLIGHT" -ForegroundColor Cyan
Write-Host "Prerequisite-Aware Eligibility Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

AddLine "HIBEYA AKAL BUDI - PHASE 008K PREFLIGHT"
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

$offlineFiles = @(
    GetFiles `
        (Join-Path $root "packages\offline\src") `
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

$allFiles = @(
    @($learnerFiles) +
    @($contentLibraryFiles) +
    @($contentSchemaFiles) +
    @($curriculumSchemaFiles) +
    @($offlineFiles) +
    @($contentCompilerFiles) +
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
    throw "Safety assertion failed: dependency/generated files entered Phase 008K scope."
}

Write-Host "PASS: source-only file set prepared ($($allFiles.Count) files)" -ForegroundColor Green
Write-Host "PASS: dependency/generated directories excluded by construction" -ForegroundColor Green

$targets = @(
    "apps\learner-web\src\journey\nextLearnerActivity.service.ts",
    "apps\learner-web\src\journey\nextLearnerActivity.service.test.ts",
    "apps\learner-web\src\journey\useNextLearnerActivity.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts",
    "packages\content-library\src\catalogue.ts",
    "packages\content-library\src\validateCatalogue.ts",
    "packages\content-schema\src\activity.schema.ts",
    "packages\curriculum-schema\src\index.ts",
    "packages\offline\src\learningJourney.repository.ts",
    "tools\content-compiler\compile.mjs",
    "tools\content-compiler\new-activity.mjs",
    "tools\content-compiler\validate-sequencing.mjs",
    "package.json"
)

foreach ($target in $targets) {
    AddFile $target
}

Write-Host "Inspecting prerequisite and eligibility contracts..." -ForegroundColor Cyan

SearchFiles `
    $allFiles `
    @(
        '"prerequisites"',
        "prerequisites:",
        "SkillPrerequisiteSchema",
        "prerequisiteSkillId",
        '"requires"',
        "requires:",
        '"unlock"',
        "unlock",
        '"eligible"',
        "eligible",
        '"completedActivityIds"',
        "completedActivityIds",
        '"skills"',
        "skills:",
        '"skillMappings"',
        "skillMappings:",
        '"sequence"',
        "sequence:",
        "getPlayableActivitiesForAgeBand",
        "resolveNextLearnerActivity"
    ) `
    "PREREQUISITE / ELIGIBILITY SEARCH"

Write-Host "Inspecting validation/compiler integration points..." -ForegroundColor Cyan

SearchFiles `
    @(
        @($contentLibraryFiles) +
        @($contentSchemaFiles) +
        @($curriculumSchemaFiles) +
        @($contentCompilerFiles)
    ) `
    @(
        "validate",
        "safeParse",
        "manifest.catalogue",
        "manifest.activity",
        "skillMappings",
        "sequence",
        "enabled",
        "ageBands",
        "writeFile",
        "catalogueSource"
    ) `
    "VALIDATION / COMPILER INTEGRATION SEARCH"

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
Write-Host "PASS: Phase 008K preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, manifest, generated catalogue, dependency, or lock files were modified." -ForegroundColor Cyan
