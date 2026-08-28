Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"

New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008j-content-sequencing-contract-$stamp.txt"

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

function SearchTree(
    [string]$RootPath,
    [string[]]$Patterns,
    [string[]]$Includes
) {
    if (-not (Test-Path $RootPath)) {
        AddLine "[SEARCH ROOT MISSING] $RootPath"
        return
    }

    foreach ($pattern in $Patterns) {
        AddLine ""
        AddLine "---- PATTERN: $pattern ----"

        Get-ChildItem `
            $RootPath `
            -Recurse `
            -File `
            -Include $Includes `
            -ErrorAction SilentlyContinue |
        Select-String `
            -Pattern $pattern `
            -SimpleMatch `
            -Context 3,10 `
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
    Write-Host "PHASE 008J PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008J PREFLIGHT" -ForegroundColor Cyan
Write-Host "Explicit Content Sequencing Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

AddLine "HIBEYA AKAL BUDI - PHASE 008J PREFLIGHT"
AddLine "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
AddLine "PowerShell: $($PSVersionTable.PSVersion)"
AddLine "Node: $((& node --version).Trim())"
AddLine "pnpm: $((& pnpm --version).Trim())"
AddLine ""

AddLine "===================================================="
AddLine "GIT STATUS"
AddLine "===================================================="

git status --short 2>&1 |
    ForEach-Object {
        AddLine $_
    }

$targets = @(
    "apps\learner-web\src\journey\nextLearnerActivity.service.ts",
    "apps\learner-web\src\journey\nextLearnerActivity.service.test.ts",
    "apps\learner-web\src\journey\useNextLearnerActivity.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.test.ts",
    "packages\content-library\src\index.ts",
    "packages\content-library\package.json",
    "packages\content-schema\src\index.ts",
    "packages\content-schema\package.json",
    "packages\curriculum-schema\src\index.ts",
    "packages\curriculum-schema\package.json",
    "content\activity-manifests\warna-merah-001.json",
    "content\activity-manifests\warna-bunga-raya-001.json",
    "package.json"
)

foreach ($target in $targets) {
    AddFile $target
}

AddLine ""
AddLine "===================================================="
AddLine "CONTENT LIBRARY FILE LIST"
AddLine "===================================================="

$contentLibraryRoot = Join-Path $root "packages\content-library"

if (Test-Path $contentLibraryRoot) {
    Get-ChildItem `
        $contentLibraryRoot `
        -Recurse `
        -File `
        -Include *.ts,*.tsx,*.json `
        -ErrorAction SilentlyContinue |
    Sort-Object FullName |
    ForEach-Object {
        AddLine (
            $_.FullName.Substring(
                $root.Length
            ).TrimStart("\")
        )
    }
}

AddLine ""
AddLine "===================================================="
AddLine "ACTIVITY MANIFEST FILE LIST"
AddLine "===================================================="

$manifestRoot = Join-Path $root "content\activity-manifests"

if (Test-Path $manifestRoot) {
    Get-ChildItem `
        $manifestRoot `
        -File `
        -Filter *.json `
        -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object {
        AddLine (
            $_.FullName.Substring(
                $root.Length
            ).TrimStart("\")
        )
    }
}

AddLine ""
AddLine "===================================================="
AddLine "SEQUENCING / ORDER / PREREQUISITE SEARCH"
AddLine "===================================================="

SearchTree `
    $root `
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
    @("*.ts","*.tsx","*.json")

AddLine ""
AddLine "===================================================="
AddLine "SCHEMA / VALIDATOR SEARCH"
AddLine "===================================================="

foreach ($schemaRoot in @(
    (Join-Path $root "packages\content-schema"),
    (Join-Path $root "packages\curriculum-schema"),
    (Join-Path $root "packages\content-library"),
    (Join-Path $root "tools\content"),
    (Join-Path $root "tools\curriculum")
)) {
    SearchTree `
        $schemaRoot `
        @(
            "z.object",
            "zod",
            "schema",
            "parse(",
            "safeParse",
            "validate",
            "manifest",
            "activityId",
            "ageBand",
            "difficulty",
            "sequence",
            "prerequisites"
        ) `
        @("*.ts","*.tsx","*.mjs","*.cjs","*.json")
}

AddLine ""
AddLine "===================================================="
AddLine "COMPILER / GENERATED CATALOGUE SEARCH"
AddLine "===================================================="

foreach ($toolRoot in @(
    (Join-Path $root "tools\content"),
    (Join-Path $root "tools\curriculum"),
    (Join-Path $root "packages\content-library")
)) {
    SearchTree `
        $toolRoot `
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
        @("*.ts","*.mjs","*.cjs","*.json")
}

AddLine ""
AddLine "===================================================="
AddLine "CURRENT ACTIVITY MANIFEST CONTENT"
AddLine "===================================================="

if (Test-Path $manifestRoot) {
    Get-ChildItem `
        $manifestRoot `
        -File `
        -Filter *.json `
        -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object {
        AddFile (
            $_.FullName.Substring(
                $root.Length
            ).TrimStart("\")
        )
    }
}

Write-Host ""
Write-Host "PASS: Phase 008J preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No source, schema, manifest, or generated catalogue files were modified." -ForegroundColor Cyan
