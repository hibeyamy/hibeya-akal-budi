Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"

New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$outFile = Join-Path $logs "phase008g-progress-contract-$stamp.txt"

function AddLine([string]$Text = "") {
    Add-Content -Path $outFile -Value $Text -Encoding UTF8
}

function AddFile([string]$RelativePath) {
    $full = Join-Path $root $RelativePath

    AddLine ""
    AddLine "===================================================="
    AddLine "FILE: $RelativePath"
    AddLine "===================================================="

    if (Test-Path $full) {
        Get-Content $full | Add-Content -Path $outFile -Encoding UTF8
    }
    else {
        AddLine "[MISSING]"
    }
}

trap {
    AddLine ""
    AddLine "FAILED"
    AddLine ($_ | Out-String)
    AddLine $_.ScriptStackTrace

    Write-Host ""
    Write-Host "PHASE 008G PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Report: $outFile" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008G PREFLIGHT" -ForegroundColor Cyan
Write-Host "Learner Progress + Completion Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

AddLine "HIBEYA AKAL BUDI - PHASE 008G PREFLIGHT"
AddLine "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
AddLine "PowerShell: $($PSVersionTable.PSVersion)"
AddLine ""

$targets = @(
    "apps\learner-web\src\App.tsx",
    "apps\learner-web\src\journey\LearnerJourneyScreen.tsx",
    "apps\learner-web\src\journey\LearnerActivityBridge.tsx",
    "apps\learner-web\src\journey\useLearnerJourney.ts",
    "apps\learner-web\src\journey\learnerJourney.ts",
    "apps\learner-web\src\shell\LearnerRuntimeShell.tsx",
    "apps\learner-web\src\shell\LearnerShell.tsx",
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\features\play\activityRegistry.ts",
    "apps\learner-web\src\features\play\selectLearnerActivity.ts"
)

foreach ($target in $targets) {
    AddFile $target
}

AddLine ""
AddLine "===================================================="
AddLine "FOCUSED SYMBOL SEARCH"
AddLine "===================================================="

$searchRoot = Join-Path $root "apps\learner-web\src"

$patterns = @(
    "recordCompletedJourneyActivity",
    "getCompletedJourney",
    "completedJourney",
    "completion",
    "completed",
    "progress",
    "progressPercent",
    "onComplete",
    "activityId",
    "getLearnerDevice",
    "learnerId",
    "profile",
    "localStorage",
    "indexedDB"
)

foreach ($pattern in $patterns) {
    AddLine ""
    AddLine "---- PATTERN: $pattern ----"

    Get-ChildItem `
        $searchRoot `
        -Recurse `
        -File `
        -Include *.ts,*.tsx `
        -ErrorAction SilentlyContinue |
    Select-String `
        -Pattern $pattern `
        -SimpleMatch `
        -Context 3,8 `
        -ErrorAction SilentlyContinue |
    ForEach-Object {
        $_.ToString() | Add-Content -Path $outFile -Encoding UTF8
    }
}

AddLine ""
AddLine "===================================================="
AddLine "PACKAGE SEARCH"
AddLine "===================================================="

$packageRoot = Join-Path $root "packages"

if (Test-Path $packageRoot) {
    Get-ChildItem `
        $packageRoot `
        -Recurse `
        -File `
        -Include *.ts,*.tsx `
        -ErrorAction SilentlyContinue |
    Select-String `
        -Pattern "completed|completion|progress|journey" `
        -Context 2,6 `
        -ErrorAction SilentlyContinue |
    ForEach-Object {
        $_.ToString() | Add-Content -Path $outFile -Encoding UTF8
    }
}

Write-Host ""
Write-Host "PASS: Phase 008G preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $outFile" -ForegroundColor White
Write-Host ""
Write-Host "No application files were modified." -ForegroundColor Cyan
