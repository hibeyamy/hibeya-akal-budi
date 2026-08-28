Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008j-content-sequencing-contract-v2-$stamp.txt"

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

function Get-ScopedFiles([string]$RootPath,[string[]]$Includes) {
    if (-not (Test-Path $RootPath)) {
        return @()
    }

    return @(
        Get-ChildItem $RootPath -Recurse -File -Include $Includes -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\node_modules\\' -and
            $_.FullName -notmatch '\\storybook-static\\' -and
            $_.FullName -notmatch '\\dist\\' -and
            $_.FullName -notmatch '\\test-results\\' -and
            $_.FullName -notmatch '\\playwright-report\\' -and
            $_.FullName -notmatch '\\\.turbo\\' -and
            $_.FullName -notmatch '\\\.git\\' -and
            $_.FullName -notmatch '\\coverage\\'
        }
    )
}

function SearchFiles([System.IO.FileInfo[]]$Files,[string[]]$Patterns,[string]$Section) {
    AddLine ""
    AddLine "===================================================="
    AddLine $Section
    AddLine "===================================================="

    if (-not $Files -or $Files.Count -eq 0) {
        AddLine "[NO FILES]"
        return
    }

    foreach ($pattern in $Patterns) {
        AddLine ""
        AddLine "---- PATTERN: $pattern ----"
        $Files |
        Select-String -Pattern $pattern -SimpleMatch -Context 3,8 -ErrorAction SilentlyContinue |
        ForEach-Object {
            $_.ToString() | Add-Content -Path $report -Encoding UTF8
        }
    }
}

trap {
    AddLine ""
    AddLine "FAILED"
    AddLine ($_ | Out-String)
    AddLine $_.ScriptStackTrace
    Write-Host ""
    Write-Host "PHASE 008J PREFLIGHT V2: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008J PREFLIGHT V2" -ForegroundColor Cyan
Write-Host "Bounded Explicit Content Sequencing Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

AddLine "HIBEYA AKAL BUDI - PHASE 008J PREFLIGHT V2"
AddLine "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
AddLine "PowerShell: $($PSVersionTable.PSVersion)"
AddLine "Node: $((& node --version).Trim())"
AddLine "pnpm: $((& pnpm --version).Trim())"

Write-Host "Collecting bounded source scopes..." -ForegroundColor Cyan

$learnerFiles = Get-ScopedFiles (Join-Path $root "apps\learner-web\src") @("*.ts","*.tsx")
$contentLibraryFiles = Get-ScopedFiles (Join-Path $root "packages\content-library") @("*.ts","*.tsx","*.json")
$contentSchemaFiles = Get-ScopedFiles (Join-Path $root "packages\content-schema") @("*.ts","*.tsx","*.json")
$curriculumSchemaFiles = Get-ScopedFiles (Join-Path $root "packages\curriculum-schema") @("*.ts","*.tsx","*.json")
$contentToolFiles = Get-ScopedFiles (Join-Path $root "tools\content") @("*.ts","*.mjs","*.cjs","*.json")
$curriculumToolFiles = Get-ScopedFiles (Join-Path $root "tools\curriculum") @("*.ts","*.mjs","*.cjs","*.json")
$curriculumContentFiles = Get-ScopedFiles (Join-Path $root "content\curriculum") @("*.json","*.ts","*.tsx")

$manifestFiles = @()
$manifestRoot = Join-Path $root "content\activity-manifests"
if (Test-Path $manifestRoot) {
    $manifestFiles = @(Get-ChildItem $manifestRoot -File -Filter *.json -ErrorAction SilentlyContinue)
}

$scopeCounts = [PSCustomObject]@{
    LearnerSource     = $learnerFiles.Count
    ContentLibrary    = $contentLibraryFiles.Count
    ContentSchema     = $contentSchemaFiles.Count
    CurriculumSchema  = $curriculumSchemaFiles.Count
    ContentTools      = $contentToolFiles.Count
    CurriculumTools   = $curriculumToolFiles.Count
    ActivityManifests = $manifestFiles.Count
    CurriculumContent = $curriculumContentFiles.Count
}

$scopeCounts | Format-Table -AutoSize
$scopeCounts | Out-String | Add-Content -Path $report -Encoding UTF8

$allFiles = @(
    $learnerFiles +
    $contentLibraryFiles +
    $contentSchemaFiles +
    $curriculumSchemaFiles +
    $contentToolFiles +
    $curriculumToolFiles +
    $manifestFiles +
    $curriculumContentFiles
)

Write-Host "PASS: bounded file set prepared ($($allFiles.Count) files)" -ForegroundColor Green

$targets = @(
    "apps\learner-web\src\journey\nextLearnerActivity.service.ts",
    "apps\learner-web\src\journey\nextLearnerActivity.service.test.ts",
    "apps\learner-web\src\journey\useNextLearnerActivity.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.test.ts",
    "packages\content-library\src\index.ts",
    "packages\content-schema\src\index.ts",
    "packages\curriculum-schema\src\index.ts",
    "package.json"
)

foreach ($target in $targets) {
    AddFile $target
}

Write-Host "Inspecting sequencing metadata..." -ForegroundColor Cyan
SearchFiles $allFiles @(
    '"sequence"',"sequence:",'"order"',"order:",'"sortOrder"',"sortOrder:",
    '"prerequisites"',"prerequisites:",'"dependsOn"',"dependsOn:",
    '"enabled"',"enabled:",'"status"',"status:","getPlayableActivitiesForAgeBand",
    "playableActivities",".sort(","localeCompare","difficulty","malaysiaElements"
) "SEQUENCING / ORDER / PREREQUISITE SEARCH"

Write-Host "Inspecting schemas and validators..." -ForegroundColor Cyan
$schemaFiles = @($contentSchemaFiles + $curriculumSchemaFiles + $contentLibraryFiles + $contentToolFiles + $curriculumToolFiles)
SearchFiles $schemaFiles @(
    "z.object","schema","safeParse","validate","manifest","activityId","ageBand",
    "difficulty","sequence","prerequisites"
) "SCHEMA / VALIDATOR SEARCH"

Write-Host "Inspecting compiler/generator flow..." -ForegroundColor Cyan
$compilerFiles = @($contentLibraryFiles + $contentToolFiles + $curriculumToolFiles)
SearchFiles $compilerFiles @(
    "writeFile","generated","manifest","activities","sort","order","sequence","index.ts"
) "COMPILER / GENERATED CATALOGUE SEARCH"

Write-Host "Capturing current activity manifests..." -ForegroundColor Cyan
AddLine ""
AddLine "===================================================="
AddLine "CURRENT ACTIVITY MANIFESTS"
AddLine "===================================================="

foreach ($manifest in ($manifestFiles | Sort-Object Name)) {
    $relative = $manifest.FullName.Substring($root.Length).TrimStart("\")
    AddFile $relative
}

Write-Host ""
Write-Host "PASS: Phase 008J preflight V2 report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, manifest, generated catalogue, or dependency files were modified." -ForegroundColor Cyan
