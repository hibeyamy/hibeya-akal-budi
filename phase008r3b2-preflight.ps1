Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3b2-preflight-" + $stamp)
$report = Join-Path $work "phase008r3b2-preflight.txt"
$zip = Join-Path $logs ("phase008r3b2-child-facing-visual-system-preflight-" + $stamp + ".zip")
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
    Log "PHASE 008R3B.2 PREFLIGHT: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.2 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Child-Facing Visual System" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log ("Generated: " + (Get-Date).ToString("o"))
Log ("Repository: " + $root)

foreach ($relative in @(
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\features\play\activityRegistry.ts",
    "apps\learner-web\src\features\play\ActivityPlayerAdapter.tsx",
    "apps\learner-web\src\journey\LearnerActivityBridge.tsx",
    "apps\learner-web\src\index.css",
    "apps\learner-web\tailwind.config.ts",
    "apps\learner-web\package.json",
    "apps\ui-storybook\stories\DraftActivityVisualReview.stories.tsx",
    "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx",
    "tools\visual-regression\tests\production-assets.spec.ts"
)) {
    Capture $relative
}

$player = Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
if (-not (Test-Path $player)) {
    throw "ActivityPlayer.tsx is missing."
}

$text = Get-Content $player -Raw

Log ""
Log "===== R3B.1 FOUNDATION VERIFICATION ====="
foreach ($needle in @(
    'data-testid="learner-choice"',
    'data-asset-id=',
    'data-visual-state=',
    'data-testid="learner-choice-visual"',
    'data-production-asset=',
    'data-fallback-asset='
)) {
    if (-not $text.Contains($needle)) {
        throw ("008R3B.1 integration hook missing: " + $needle)
    }
    Log ("PASS: " + $needle)
}

Log ""
Log "===== CURRENT CHILD-FACING STYLE TOKENS ====="
foreach ($needle in @(
    "min-h-40",
    "rounded-3xl",
    "border-2",
    "px-4",
    "py-6",
    "active:scale-95",
    "focus:ring-4",
    "border-emerald-500",
    "border-rose-400",
    "border-amber-500",
    "text-base",
    "font-semibold",
    "grid",
    "gap-"
)) {
    $hits = @(
        Select-String -Path $player -SimpleMatch -Pattern $needle -Context 2,4 -ErrorAction SilentlyContinue
    )
    Log ($needle + " | hits=" + $hits.Count)
    foreach ($hit in $hits) { Log $hit.ToString() }
}

Log ""
Log "===== FEEDBACK + COMPLETION CONTRACT ====="
foreach ($needle in @(
    "feedback",
    "Betul",
    "Cuba lagi",
    "completed",
    "selectedState",
    "answers.at(-1)",
    "aria-live",
    "disabled="
)) {
    $hits = @(
        Select-String -Path $player -SimpleMatch -Pattern $needle -Context 3,8 -ErrorAction SilentlyContinue
    )
    Log ($needle + " | hits=" + $hits.Count)
    foreach ($hit in $hits) { Log $hit.ToString() }
}

Log ""
Log "===== RESPONSIVE STRUCTURE ====="
foreach ($needle in @(
    "sm:",
    "md:",
    "lg:",
    "grid-cols",
    "max-w",
    "w-full",
    "h-40",
    "w-40",
    "sm:h-44",
    "sm:w-44"
)) {
    $hits = @(
        Select-String -Path $player -SimpleMatch -Pattern $needle -Context 2,4 -ErrorAction SilentlyContinue
    )
    Log ($needle + " | hits=" + $hits.Count)
    foreach ($hit in $hits) { Log $hit.ToString() }
}

Log ""
Log "===== DESIGN-SYSTEM DECISIONS TO MAKE ====="
Log "1. Establish one coherent child-facing card hierarchy without changing activity mechanics."
Log "2. Preserve the 56px-or-larger interaction standard and touch-manipulation behaviour."
Log "3. Make selected/correct/incorrect states visually distinct without relying on colour alone."
Log "4. Keep rich artwork dominant while preventing crop, distortion and layout shift."
Log "5. Improve prompt/feedback hierarchy for pre-reader and early-reader use."
Log "6. Keep Malay labels and current curriculum content unchanged."
Log "7. Preserve keyboard focus and screen-reader semantics."
Log "8. Avoid animation that can distract from the learning task; use restrained state transitions."
Log "9. Reuse Tailwind/current CSS infrastructure; add no UI dependency."
Log "10. Build the visual system at ActivityPlayer rather than creating a parallel renderer."

Log ""
Log "PHASE 008R3B.2 PREFLIGHT: PASS"
Log "No learner source, activity content, dependency, asset or lockfile was modified."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3B.2 PREFLIGHT: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
