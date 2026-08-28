Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"

New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008h-unique-completion-contract-$stamp.txt"

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

function AddSearch(
    [string]$RootPath,
    [string[]]$Patterns
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
            -Include *.ts,*.tsx,*.json `
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
    Write-Host "PHASE 008H PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008H PREFLIGHT" -ForegroundColor Cyan
Write-Host "Unique Completion + Progress Integrity Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

AddLine "HIBEYA AKAL BUDI - PHASE 008H PREFLIGHT"
AddLine "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
AddLine "PowerShell: $($PSVersionTable.PSVersion)"
AddLine "CLR: $($PSVersionTable.CLRVersion)"
AddLine ""

# Read-only repository state snapshot.
AddLine "===================================================="
AddLine "GIT STATUS"
AddLine "===================================================="

git status --short 2>&1 |
    ForEach-Object {
        AddLine $_
    }

# Current 008G implementation.
$targets = @(
    "apps\learner-web\src\journey\LearnerJourneyScreen.tsx",
    "apps\learner-web\src\journey\learnerProgress.ts",
    "apps\learner-web\src\journey\learnerProgress.test.ts",
    "apps\learner-web\src\journey\useLearnerProgress.ts",
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\features\play\activityRegistry.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts",
    "packages\offline\src\index.ts",
    "packages\offline\package.json",
    "packages\content-library\src\index.ts",
    "packages\content-library\package.json"
)

foreach ($target in $targets) {
    AddFile $target
}

# Offline persistence implementation and schema/migrations.
AddLine ""
AddLine "===================================================="
AddLine "OFFLINE PACKAGE FILE LIST"
AddLine "===================================================="

$offlineRoot = Join-Path $root "packages\offline"

if (Test-Path $offlineRoot) {
    Get-ChildItem `
        $offlineRoot `
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
AddLine "OFFLINE COMPLETION / SCHEMA SEARCH"
AddLine "===================================================="

AddSearch `
    (Join-Path $root "packages\offline") `
    @(
        "getLearnerJourneyState",
        "recordCompletedJourneyActivity",
        "completedSessionCount",
        "lastCompletedActivityId",
        "activityId",
        "indexedDB",
        "IDB",
        "version",
        "migration",
        "schema",
        "store",
        "objectStore",
        "localStorage"
    )

AddLine ""
AddLine "===================================================="
AddLine "LEARNER COMPLETION CALL SITES"
AddLine "===================================================="

AddSearch `
    (Join-Path $root "apps\learner-web\src") `
    @(
        "recordCompletedJourneyActivity",
        "completeLocalSession",
        "onComplete",
        "completedSessionCount",
        "lastCompletedActivityId",
        "calculateLearnerProgressPercent",
        "refreshProgress"
    )

AddLine ""
AddLine "===================================================="
AddLine "ACTIVITY CATALOGUE / ID CONTRACT"
AddLine "===================================================="

AddSearch `
    (Join-Path $root "packages\content-library") `
    @(
        "getPlayableActivitiesForAgeBand",
        "activityId",
        "id:",
        "ageBand",
        "status",
        "playable"
    )

AddLine ""
AddLine "===================================================="
AddLine "TEST COVERAGE SEARCH"
AddLine "===================================================="

AddSearch `
    $root `
    @(
        "completedSessionCount",
        "recordCompletedJourneyActivity",
        "getLearnerJourneyState",
        "learnerProgress",
        "qa:journey"
    )

# Package scripts relevant to migration/testing.
AddLine ""
AddLine "===================================================="
AddLine "ROOT PACKAGE SCRIPTS"
AddLine "===================================================="

$packageJson = Join-Path $root "package.json"

if (Test-Path $packageJson) {
    Get-Content $packageJson |
        Add-Content `
            -Path $report `
            -Encoding UTF8
}

Write-Host ""
Write-Host "PASS: Phase 008H preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No application or persistence files were modified." -ForegroundColor Cyan
