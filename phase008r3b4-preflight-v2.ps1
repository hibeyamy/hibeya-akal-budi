Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3b4-preflight-v2-" + $stamp)
$report = Join-Path $work "phase008r3b4-preflight-v2.txt"
$zip = Join-Path $logs ("phase008r3b4-responsive-qa-preflight-v2-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
    Write-Host $Text
}
function Save-Zip {
    if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
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
    Log "PHASE 008R3B.4 PREFLIGHT V2: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.4 PREFLIGHT V2" -ForegroundColor Cyan
Write-Host "Responsive QA + Production Route/Session Discovery" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log ("Generated: " + (Get-Date).ToString("o"))
Log ("Repository: " + $root)

foreach ($relative in @(
    "apps\learner-web\package.json",
    "apps\learner-web\vite.config.ts",
    "apps\learner-web\src\main.tsx",
    "apps\learner-web\src\App.tsx",
    "apps\learner-web\src\shell\LearnerShell.tsx",
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\features\play\ActivityPlayerAdapter.tsx",
    "apps\learner-web\src\journey\LearnerActivityBridge.tsx",
    "apps\learner-web\src\journey\LearnerJourneyScreen.tsx",
    "tools\visual-regression\playwright.config.ts",
    "tools\visual-regression\tests\learner-production-state.spec.ts",
    "tools\visual-regression\tests\learner-journey.spec.ts",
    "package.json",
    "pnpm-workspace.yaml"
)) { Capture $relative }

$learnerRoot = Join-Path $root "apps\learner-web\src"
$files = @(
    Get-ChildItem -Path $learnerRoot -Recurse -File -Include *.ts,*.tsx,*.json -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch "\\node_modules\\" -and
        $_.FullName -notmatch "\\dist\\"
    }
)

Log ""
Log "===== ROUTE / BOOTSTRAP / SESSION SEARCH ====="

$needles = @(
    'createRoot',
    'BrowserRouter',
    'MemoryRouter',
    'Routes',
    'Route',
    'window.location',
    'URLSearchParams',
    'localStorage',
    'sessionStorage',
    'StoredSession',
    'recoverySession',
    'activation',
    'journey',
    'activity',
    'ActivityPlayerAdapter',
    'LearnerActivityBridge',
    'data-testid="activity-player"'
)

foreach ($needle in $needles) {
    $hits = @(
        $files |
        Select-String -SimpleMatch -Pattern $needle -Context 2,8 -ErrorAction SilentlyContinue
    )
    Log ""
    Log ("-- " + $needle + " | hits=" + $hits.Count + " --")
    foreach ($hit in $hits) { Log $hit.ToString() }
}

Log ""
Log "===== PACKAGE SCRIPTS ====="
foreach ($relative in @("apps\learner-web\package.json","package.json")) {
    $full = Join-Path $root $relative
    if (-not (Test-Path $full)) { continue }
    $json = Get-Content -Path $full -Raw | ConvertFrom-Json
    Log ("-- " + $relative + " --")
    if ($json.scripts) {
        foreach ($property in $json.scripts.PSObject.Properties) {
            Log ($property.Name + " = " + $property.Value)
        }
    }
}

Log ""
Log "===== RESPONSIVE QA DECISIONS ====="
Log "1. Determine the real learner production entry route and whether an activity is reachable without synthetic state injection."
Log "2. Determine whether existing learner-journey Playwright setup already provisions the required state/session."
Log "3. Reuse existing server lifecycle if available; otherwise serve learner dist with the existing dependency-free Node approach."
Log "4. Execute genuine production interactions at mobile, tablet and desktop dimensions."
Log "5. Assert idle -> incorrect/retry -> correct/completed where the actual mechanic allows it."
Log "6. Verify learner choice targets retain appropriate child-sized interaction dimensions."
Log "7. Verify production images load, remain object-contained and do not overflow their cards."
Log "8. Verify feedback and completion regions remain visible without horizontal overflow."
Log "9. Do not bypass activation/session/journey contracts merely to force a screenshot."
Log "10. Do not create test-only correctness or fake learner state."

Log ""
Log "PHASE 008R3B.4 PREFLIGHT V2: PASS"
Log "No learner source, test source, dependency, content, asset or lockfile was modified."
Save-Zip

Write-Host ""
Write-Host "PHASE 008R3B.4 PREFLIGHT V2: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
