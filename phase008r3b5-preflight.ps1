Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3b5-preflight-" + $stamp)
$report = Join-Path $work "phase008r3b5-preflight.txt"
$zip = Join-Path $logs ("phase008r3b5-accessibility-interaction-preflight-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Save-Zip {
    if (Test-Path $zip) { Remove-Item -Path $zip -Force -ErrorAction SilentlyContinue }
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
    Log "PHASE 008R3B.5 PREFLIGHT: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.5 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Accessibility + Interaction QA Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log ("Generated: " + (Get-Date).ToString("o"))
Log ("Repository: " + $root)

foreach ($relative in @(
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\index.css",
    "apps\learner-web\package.json",
    "apps\ui-storybook\.storybook\preview.ts",
    "apps\ui-storybook\.storybook\preview.tsx",
    "apps\ui-storybook\stories\LearnerJourney.stories.tsx",
    "apps\ui-storybook\package.json",
    "tools\visual-regression\playwright.config.ts",
    "tools\visual-regression\tests\learner-responsive-production.spec.ts",
    "tools\visual-regression\tests\learner-journey.spec.ts",
    "tools\visual-regression\tests\production-assets.spec.ts",
    "package.json"
)) {
    Capture $relative
}

$searchRoots = @(
    (Join-Path $root "apps\learner-web\src"),
    (Join-Path $root "apps\ui-storybook"),
    (Join-Path $root "tools\visual-regression")
)

$files = @()
foreach ($searchRoot in $searchRoots) {
    if (-not (Test-Path $searchRoot)) { continue }
    $files += @(
        Get-ChildItem -Path $searchRoot -Recurse -File -Include *.ts,*.tsx,*.css,*.json -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\dist\\" -and
            $_.FullName -notmatch "\\storybook-static\\" -and
            $_.FullName -notmatch "\\test-results\\" -and
            $_.FullName -notmatch "\\playwright-report\\"
        }
    )
}

Log ""
Log "===== ACCESSIBILITY DEPENDENCY DISCOVERY ====="

foreach ($pkg in @(
    (Join-Path $root "package.json"),
    (Join-Path $root "apps\learner-web\package.json"),
    (Join-Path $root "apps\ui-storybook\package.json")
)) {
    if (-not (Test-Path $pkg)) { continue }
    $json = Get-Content -Path $pkg -Raw | ConvertFrom-Json
    Log ("-- " + $pkg.Substring($root.Length).TrimStart("\") + " --")
    $deps = @()
    if ($json.dependencies) { $deps += $json.dependencies.PSObject.Properties.Name }
    if ($json.devDependencies) { $deps += $json.devDependencies.PSObject.Properties.Name }

    foreach ($needle in @(
        "@axe-core/playwright",
        "axe-core",
        "@storybook/addon-a11y",
        "eslint-plugin-jsx-a11y",
        "@testing-library/react",
        "@testing-library/user-event",
        "playwright",
        "@playwright/test"
    )) {
        if ($deps -contains $needle) {
            Log ("FOUND: " + $needle)
        }
    }
}

Log ""
Log "===== CURRENT A11Y / INTERACTION CONTRACTS ====="

foreach ($needle in @(
    "aria-live",
    "aria-atomic",
    "aria-pressed",
    "aria-label",
    "aria-hidden",
    "disabled=",
    "focus-visible",
    "focus:ring",
    "tabIndex",
    "role=",
    "touch-manipulation",
    "min-h-14",
    "min-h-40",
    "active:scale",
    "prefers-reduced-motion",
    "motion-reduce",
    "outline-none",
    "data-feedback-state",
    "data-activity-state"
)) {
    $hits = @($files | Select-String -SimpleMatch -Pattern $needle -Context 2,6 -ErrorAction SilentlyContinue)
    Log ""
    Log ("-- " + $needle + " | hits=" + $hits.Count + " --")
    foreach ($hit in $hits) { Log $hit.ToString() }
}

Log ""
Log "===== PLAYWRIGHT A11Y / KEYBOARD COVERAGE ====="

foreach ($needle in @(
    "keyboard.press",
    "toBeFocused",
    "aria-live",
    "axe",
    "accessibility",
    "disabled",
    "focus",
    "boundingBox",
    "56"
)) {
    $hits = @($files | Select-String -SimpleMatch -Pattern $needle -Context 2,8 -ErrorAction SilentlyContinue)
    Log ""
    Log ("-- " + $needle + " | hits=" + $hits.Count + " --")
    foreach ($hit in $hits) { Log $hit.ToString() }
}

Log ""
Log "===== PHASE 008R3B.5 DECISION RULES ====="
Log "1. Reuse existing Playwright and Storybook infrastructure."
Log "2. Add no accessibility dependency if current tooling can verify the required contracts."
Log "3. Reuse axe or Storybook a11y only if already installed."
Log "4. Keyboard QA must exercise the real learner activity route used by R3B.4."
Log "5. Correct/incorrect feedback must remain understandable without colour alone."
Log "6. Disabled choices after completion must be non-interactive by keyboard and pointer."
Log "7. Focus-visible styling must remain observable during keyboard interaction."
Log "8. aria-live feedback should announce committed answer feedback without duplicate or stale state."
Log "9. Touch-target validation should retain the existing >=56px learner standard."
Log "10. Reduced-motion treatment should only be added where current transitions justify it."
Log "11. Do not fabricate screen-reader-only state or accessibility-only correctness."
Log "12. Do not change curriculum text, mechanics, mastery, progression or production assets."

Log ""
Log "PHASE 008R3B.5 PREFLIGHT: PASS"
Log "No learner source, Storybook source, test source, dependency, content, asset or lockfile was modified."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3B.5 PREFLIGHT: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
