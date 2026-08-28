Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3b3-preflight-" + $stamp)
$report = Join-Path $work "phase008r3b3-preflight.txt"
$zip = Join-Path $logs ("phase008r3b3-activity-states-preflight-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Save-Zip {
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

function Capture([string]$Relative) {
    $source = Join-Path $root $Relative
    if (Test-Path $source) {
        $name = $Relative.Replace("\","__").Replace("/","__")
        Copy-Item $source (Join-Path $work $name) -Force
        Log ("CAPTURED: " + $Relative)
    } else {
        Log ("MISSING: " + $Relative)
    }
}

trap {
    Log ""
    Log "PHASE 008R3B.3 PREFLIGHT: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.3 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Activity States + State-Testability Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log ("Generated: " + (Get-Date).ToString("o"))
Log ("Repository: " + $root)

foreach ($relative in @(
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\features\play\activityRegistry.ts",
    "apps\learner-web\src\features\play\ActivityPlayerAdapter.tsx",
    "apps\learner-web\src\journey\LearnerActivityBridge.tsx",
    "apps\ui-storybook\stories\DraftActivityVisualReview.stories.tsx",
    "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx",
    "tools\visual-regression\tests\production-assets.spec.ts",
    "tools\visual-regression\serve-storybook-static.mjs",
    "apps\learner-web\package.json",
    "apps\ui-storybook\package.json",
    "package.json"
)) {
    Capture $relative
}

$player = Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
if (-not (Test-Path $player)) { throw "ActivityPlayer.tsx missing" }
$text = Get-Content $player -Raw

Log ""
Log "===== R3B.2 FOUNDATION ====="
foreach ($needle in @(
    'data-testid="learner-activity-card"',
    'data-testid="learner-choice"',
    'data-visual-state=',
    'data-testid="learner-choice-state-icon"',
    'data-testid="learner-feedback"',
    'aria-atomic="true"',
    'data-testid="learner-completion"'
)) {
    if (-not $text.Contains($needle)) { throw ("R3B.2 contract missing: " + $needle) }
    Log ("PASS: " + $needle)
}

Log ""
Log "===== STATE SOURCE MAP ====="
foreach ($needle in @(
    "selectedId",
    "selectedState",
    "answers.at(-1)",
    "feedback",
    "completed",
    "loading",
    "error",
    "setFeedback",
    "setSelectedId",
    "setCompleted",
    "handleAnswer",
    "handleContinue"
)) {
    $hits = @(Select-String -Path $player -SimpleMatch -Pattern $needle -Context 3,10 -ErrorAction SilentlyContinue)
    Log ($needle + " | hits=" + $hits.Count)
    foreach ($hit in $hits) { Log $hit.ToString() }
}

Log ""
Log "===== STATE COVERAGE QUESTIONS ====="
Log "1. Can idle be rendered deterministically without user interaction?"
Log "2. Can selected be distinguished from submitted feedback?"
Log "3. Can correct be asserted from DOM state and non-colour cue?"
Log "4. Can incorrect/retry be asserted from DOM state and non-colour cue?"
Log "5. Can completed be asserted independently from the choice state?"
Log "6. Is loading represented by the current ActivityPlayer or only upstream?"
Log "7. Is error represented by the current ActivityPlayer or only upstream?"
Log "8. Can Storybook exercise these states without duplicating answer/mastery logic?"
Log "9. Can Playwright drive real interactions instead of fabricated visual-only states?"
Log "10. Which state transitions need explicit regression tests?"

Log ""
Log "===== STATE INVARIANTS ====="
Log "A. No state test may bypass or replace mechanic.submitAnswer()."
Log "B. Correctness must remain content/mechanic-owned."
Log "C. Mastery and journey completion must remain production-owned."
Log "D. Visual-state hooks may expose state but must not become state sources."
Log "E. Correct/incorrect feedback must not rely on colour alone."
Log "F. Disabled/completed state must remain keyboard and pointer safe."
Log "G. Loading/error UI should only be added where a real production state exists."
Log "H. No synthetic loading/error state should be invented merely for Storybook."

Log ""
Log "PHASE 008R3B.3 PREFLIGHT: PASS"
Log "No learner source, Storybook source, test source, content, dependency or asset was modified."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3B.3 PREFLIGHT: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
