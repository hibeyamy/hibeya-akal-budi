Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3b-preflight-" + $stamp)
$report = Join-Path $work "phase008r3b-preflight.txt"
$zip = Join-Path $logs ("phase008r3b-learner-visual-integration-preflight-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Save-Zip {
    if (Test-Path $zip) {
        Remove-Item -Path $zip -Force -ErrorAction SilentlyContinue
    }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

function Collect-Files([string]$Path,[string[]]$Patterns) {
    if (-not (Test-Path $Path)) { return @() }
    return @(
        Get-ChildItem -Path $Path -Recurse -File -Include $Patterns -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\dist\\" -and
            $_.FullName -notmatch "\\storybook-static\\" -and
            $_.FullName -notmatch "\\test-results\\" -and
            $_.FullName -notmatch "\\playwright-report\\" -and
            $_.FullName -notmatch "\\\.git\\"
        }
    )
}

function Search-Files([object[]]$Files,[string[]]$Needles,[string]$Section) {
    Log ""
    Log ("===== " + $Section + " =====")

    foreach ($needle in $Needles) {
        Log ""
        Log ("-- " + $needle + " --")

        $hits = @(
            @($Files) |
            Select-String -SimpleMatch -Pattern $needle -Context 2,6 -ErrorAction SilentlyContinue
        )

        Log ("HITS: " + $hits.Count)

        foreach ($hit in $hits) {
            Log ($hit.ToString())
        }
    }
}

trap {
    Log ""
    Log "PHASE 008R3B PREFLIGHT: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ""
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B PREFLIGHT" -ForegroundColor Cyan
Write-Host "Learner Experience Visual Integration Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log ("Generated: " + (Get-Date).ToString("o"))
Log ("Repository: " + $root)

$learnerRoot = Join-Path $root "apps\learner-web\src"
$storybookRoot = Join-Path $root "apps\ui-storybook"
$visualRoot = Join-Path $root "tools\visual-regression"
$assetsRoot = Join-Path $root "packages\assets\src"
$contentRoot = Join-Path $root "packages\content-library\src"

foreach ($required in @(
    $learnerRoot,
    $storybookRoot,
    $visualRoot,
    $assetsRoot,
    $contentRoot
)) {
    if (-not (Test-Path $required)) {
        throw ("Required scope missing: " + $required)
    }
}

$learnerFiles = @(Collect-Files $learnerRoot @("*.ts","*.tsx","*.css","*.json"))
$storybookFiles = @(Collect-Files $storybookRoot @("*.ts","*.tsx","*.css","*.json"))
$visualFiles = @(Collect-Files $visualRoot @("*.ts","*.tsx","*.js","*.mjs","*.json"))
$assetFiles = @(Collect-Files $assetsRoot @("*.ts","*.tsx","*.json"))
$contentFiles = @(Collect-Files $contentRoot @("*.ts","*.tsx","*.json"))

Log ""
Log "===== SCOPE COUNTS ====="
Log ("learner files: " + $learnerFiles.Count)
Log ("storybook files: " + $storybookFiles.Count)
Log ("visual regression files: " + $visualFiles.Count)
Log ("asset files: " + $assetFiles.Count)
Log ("content files: " + $contentFiles.Count)

Search-Files `
    @($learnerFiles + $storybookFiles) `
    @(
        "ActivityPlayer",
        "LearnerJourney",
        "getAsset(",
        "asset.value",
        "asset.type",
        "img",
        "emoji",
        "placeholder",
        "fallback",
        "implementationKey",
        "tap-choice"
    ) `
    "LEARNER RENDERING + ASSET CONSUMPTION"

Search-Files `
    @($learnerFiles + $storybookFiles) `
    @(
        "correct",
        "incorrect",
        "retry",
        "selected",
        "completed",
        "feedback",
        "loading",
        "error",
        "disabled",
        "aria-live"
    ) `
    "ACTIVITY INTERACTION STATES"

Search-Files `
    @($learnerFiles + $storybookFiles + $visualFiles) `
    @(
        "min-h-",
        "min-w-",
        "56",
        "touch",
        "grid-cols",
        "sm:",
        "md:",
        "lg:",
        "viewport",
        "setViewportSize",
        "boundingBox",
        "toHaveScreenshot",
        "screenshot"
    ) `
    "RESPONSIVE + TOUCH TARGET CONTRACT"

Search-Files `
    @($visualFiles + $storybookFiles) `
    @(
        "learner-journey",
        "production-assets",
        "iframe.html",
        "Storybook",
        "chromium",
        "mobile",
        "tablet",
        "desktop"
    ) `
    "EXISTING STORYBOOK + PLAYWRIGHT COVERAGE"

Search-Files `
    @($learnerFiles + $storybookFiles + $assetFiles + $contentFiles) `
    @(
        "apple-red",
        "apple-green",
        "banana-yellow",
        "hibiscus-red",
        "hibiscus-yellow",
        "hibiscus-purple"
    ) `
    "PRODUCTION ASSET USAGE MAP"

Log ""
Log "===== LEARNER VISUAL FILE INVENTORY ====="

foreach ($file in ($learnerFiles | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($root.Length).TrimStart("\")
    Log ($relative + " | " + $file.Length + " bytes")
}

Log ""
Log "===== PRELIMINARY INTEGRATION RULES ====="
Log "1. Preserve all learning logic, sequencing, mastery and progression contracts."
Log "2. Learner-facing rich illustrations must resolve through getAsset()."
Log "3. Do not hard-code physical .png/.webp/.svg paths in learner components."
Log "4. Reuse existing activity mechanics; visual work must not introduce duplicate learning logic."
Log "5. Standardise illustration containers and object-fit behaviour only where current code supports it safely."
Log "6. Keep touch targets at or above the existing learner standard."
Log "7. Define explicit visual states for idle, selected, correct, incorrect, retry, completed, loading and error."
Log "8. Use current Storybook/Playwright infrastructure for mobile, tablet and desktop verification."
Log "9. Any placeholder/emoji fallback still visible in production learner UI should be identified before replacement."
Log "10. Preflight is read-only: no learner source, Storybook source, manifest or asset is modified."

Log ""
Log "===== REQUIRED IMPLEMENTATION DECISIONS ====="
Log "A. Which learner component is the single visual boundary for activity options?"
Log "B. Are all current mechanics using the same asset renderer or multiple duplicated render paths?"
Log "C. Which components still use emoji/placeholders despite approved production assets?"
Log "D. What responsive layout rules already exist and should be retained?"
Log "E. Which current feedback states need visual-system normalisation?"
Log "F. Which existing Storybook story should become the canonical learner visual-integration baseline?"
Log "G. Which Playwright tests can be extended rather than duplicated?"
Log "H. Can the visual integration be implemented without new dependencies?"

Log ""
Log "PHASE 008R3B PREFLIGHT: PASS"
Log "No repository source, manifest, asset, dependency or lockfile was modified."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3B PREFLIGHT: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
