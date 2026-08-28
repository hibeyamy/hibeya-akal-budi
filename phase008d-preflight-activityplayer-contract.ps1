Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$outFile = Join-Path $logs "phase008d-activityplayer-contract-$stamp.txt"

$targets = @(
  "apps\learner-web\src\features\play\ActivityPlayer.tsx",
  "apps\learner-web\src\features\play\activityRegistry.ts",
  "apps\learner-web\src\features\play\selectLearnerActivity.ts",
  "apps\learner-web\src\main.tsx",
  "apps\learner-web\src\App.tsx",
  "apps\learner-web\src\journey\LearnerActivityBridge.tsx",
  "apps\learner-web\src\journey\LearnerJourneyScreen.tsx",
  "apps\learner-web\src\journey\index.ts"
)

function Add-Line([string]$Text = "") {
  Add-Content -Path $outFile -Value $Text -Encoding UTF8
}

function Add-File([string]$RelativePath) {
  $full = Join-Path $root $RelativePath

  Add-Line ""
  Add-Line "===================================================="
  Add-Line "FILE: $RelativePath"
  Add-Line "===================================================="

  if (Test-Path $full) {
    Get-Content $full | Add-Content -Path $outFile -Encoding UTF8
  }
  else {
    Add-Line "[MISSING]"
  }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008D PREFLIGHT" -ForegroundColor Cyan
Write-Host "ActivityPlayer Runtime Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Add-Line "HIBEYA AKAL BUDI - PHASE 008D PREFLIGHT"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Add-Line ""

foreach ($target in $targets) {
  Add-File $target
}

Add-Line ""
Add-Line "===================================================="
Add-Line "FOCUSED SYMBOL SEARCH"
Add-Line "===================================================="

$searchPath = Join-Path $root "apps\learner-web\src"

$patterns = @(
  "ActivityPlayer",
  "interface ActivityPlayer",
  "type ActivityPlayer",
  "onComplete",
  "onExit",
  "onClose",
  "activityId",
  "ResolvedPlayableActivity",
  "getActivity",
  "getPlayable",
  "completeLocalSession",
  "recordCompletedJourneyActivity"
)

foreach ($pattern in $patterns) {
  Add-Line ""
  Add-Line "---- PATTERN: $pattern ----"

  Get-ChildItem $searchPath -Recurse -File -Include *.ts,*.tsx |
    Select-String -Pattern $pattern -SimpleMatch -Context 3,6 -ErrorAction SilentlyContinue |
    ForEach-Object {
      $_.ToString() | Add-Content -Path $outFile -Encoding UTF8
    }
}

Write-Host ""
Write-Host "PASS: Phase 008D preflight report created" -ForegroundColor Green
Write-Host "Report:" -ForegroundColor Cyan
Write-Host "  $outFile" -ForegroundColor White
Write-Host ""
Write-Host "Copy or upload this report for the typed ActivityPlayer adapter implementation." -ForegroundColor Yellow
