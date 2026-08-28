Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$report = Join-Path $logs "phase008i-resume-next-activity-contract-$stamp.txt"

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
    } else {
        AddLine "[MISSING]"
    }
}

function SearchTree([string]$RootPath,[string[]]$Patterns) {
    if (-not (Test-Path $RootPath)) {
        AddLine "[SEARCH ROOT MISSING] $RootPath"
        return
    }

    foreach ($pattern in $Patterns) {
        AddLine ""
        AddLine "---- PATTERN: $pattern ----"

        Get-ChildItem $RootPath -Recurse -File -Include *.ts,*.tsx,*.json -ErrorAction SilentlyContinue |
            Select-String -Pattern $pattern -SimpleMatch -Context 3,10 -ErrorAction SilentlyContinue |
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
    Write-Host "PHASE 008I PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $report" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008I PREFLIGHT" -ForegroundColor Cyan
Write-Host "Resume / Next Activity Selection Contract" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

AddLine "HIBEYA AKAL BUDI - PHASE 008I PREFLIGHT"
AddLine "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
AddLine "PowerShell: $($PSVersionTable.PSVersion)"
AddLine ""

AddLine "===================================================="
AddLine "GIT STATUS"
AddLine "===================================================="
git status --short 2>&1 | ForEach-Object { AddLine $_ }

$targets = @(
    "apps\learner-web\src\journey\LearnerJourneyScreen.tsx",
    "apps\learner-web\src\journey\useLearnerJourney.ts",
    "apps\learner-web\src\journey\learnerJourney.ts",
    "apps\learner-web\src\journey\useLearnerProgress.ts",
    "apps\learner-web\src\journey\learnerProgress.ts",
    "apps\learner-web\src\features\play\activityRegistry.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts",
    "apps\learner-web\src\shell\LearnerHome.tsx",
    "apps\learner-web\src\shell\LearnerRuntimeShell.tsx",
    "packages\offline\src\learningJourney.repository.ts",
    "packages\content-library\src\index.ts"
)

foreach ($target in $targets) {
    AddFile $target
}

AddLine ""
AddLine "===================================================="
AddLine "RESUME / CONTINUE / SELECTION SEARCH"
AddLine "===================================================="

SearchTree (Join-Path $root "apps\learner-web\src") @(
    "continue",
    "Sambung",
    "resume",
    "next",
    "openActivity",
    "selectedActivityId",
    "lastCompletedActivityId",
    "completedActivityIds",
    "getPlayableActivitiesForAgeBand",
    "selectLearnerActivity",
    "activity.id"
)

AddLine ""
AddLine "===================================================="
AddLine "CONTENT ORDER / PLAYABLE CATALOGUE SEARCH"
AddLine "===================================================="

SearchTree (Join-Path $root "packages\content-library") @(
    "getPlayableActivitiesForAgeBand",
    "sort",
    "order",
    "sequence",
    "activity.id",
    "ageBand",
    "playable"
)

AddLine ""
AddLine "===================================================="
AddLine "TEST COVERAGE SEARCH"
AddLine "===================================================="

SearchTree (Join-Path $root "apps\learner-web\src") @(
    "continue opens",
    "Sambung belajar",
    "resume",
    "next activity",
    "lastCompletedActivityId",
    "completedActivityIds"
)

AddLine ""
AddLine "===================================================="
AddLine "ROOT PACKAGE SCRIPTS"
AddLine "===================================================="

$packageJson = Join-Path $root "package.json"
if (Test-Path $packageJson) {
    Get-Content $packageJson | Add-Content -Path $report -Encoding UTF8
}

Write-Host ""
Write-Host "PASS: Phase 008I preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $report" -ForegroundColor White
Write-Host ""
Write-Host "No application or persistence files were modified." -ForegroundColor Cyan
