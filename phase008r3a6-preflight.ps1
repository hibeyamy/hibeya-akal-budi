Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3a6-preflight-" + $stamp)
$report = Join-Path $work "phase008r3a6-preflight.txt"
$zip = Join-Path $logs ("phase008r3a6-production-visual-governance-preflight-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Save-Zip {
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

function Add-File([string]$Relative) {
    $full = Join-Path $root $Relative
    Log ""
    Log ("===== FILE: " + $Relative + " =====")
    if (-not (Test-Path $full)) {
        Log "STATUS: NOT FOUND"
        return
    }

    $item = Get-Item $full
    Log ("SIZE: " + $item.Length + " bytes")
    Log ("SHA256: " + (Get-FileHash $full -Algorithm SHA256).Hash)

    Get-Content -Path $full -ErrorAction SilentlyContinue |
        ForEach-Object { Log $_ }
}

trap {
    Log ""
    Log "PHASE 008R3A.6 PREFLIGHT: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ""
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.6 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Production Visual Regression + Asset Governance Close-Out" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log ("Generated: " + (Get-Date).ToString("o"))
Log ("Repository: " + $root)

$ids = @(
    "apple-red",
    "apple-green",
    "banana-yellow",
    "hibiscus-red",
    "hibiscus-yellow",
    "hibiscus-purple"
)

Log ""
Log "===== PRODUCTION ASSET CUTOVER CHECK ====="

$registryPath = Join-Path $root "packages\assets\src\generated\commercialRegistry.generated.ts"
if (-not (Test-Path $registryPath)) {
    throw "Commercial registry is missing."
}
$registry = Get-Content -Path $registryPath -Raw

foreach ($id in $ids) {
    $webp = Join-Path $root ("packages\assets\src\generated\" + $id + ".webp")
    if (-not (Test-Path $webp)) {
        throw ("Missing production WebP: " + $id)
    }

    $hasWebp = $registry -match [Regex]::Escape("./" + $id + ".webp")
    $hasSvg = $registry -match [Regex]::Escape("./" + $id + ".svg")

    Log ($id + " | webp=" + $hasWebp + " | svg=" + $hasSvg + " | bytes=" + (Get-Item $webp).Length)

    if (-not $hasWebp) {
        throw ("Registry does not expose WebP for " + $id)
    }

    if ($hasSvg) {
        throw ("Registry still exposes legacy SVG for " + $id)
    }
}

Log "PASS: all six production learning assets resolve to WebP"

Log ""
Log "===== LEGACY SVG RETIREMENT CHECK ====="

foreach ($id in $ids) {
    $runtimeSvg = Join-Path $root ("packages\assets\src\generated\" + $id + ".svg")
    $fruitLegacy = Join-Path $root ("packages\assets\source\legacy\fruit\" + $id + ".svg")
    $floraLegacy = Join-Path $root ("packages\assets\source\legacy\flora\" + $id + ".svg")

    Log ($id + " | runtime-svg=" + (Test-Path $runtimeSvg) + " | legacy-fruit=" + (Test-Path $fruitLegacy) + " | legacy-flora=" + (Test-Path $floraLegacy))
}

Log ""
Log "===== RELEVANT CONTRACT FILES ====="

foreach ($relative in @(
    "packages\assets\src\index.ts",
    "packages\assets\src\metadata.ts",
    "packages\assets\source\raster-assets.json",
    "packages\assets\source\visual-replacement-plan.json",
    "packages\assets\source\asset-migration.json",
    "packages\assets\src\generated\commercialRegistry.generated.ts",
    "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx",
    "apps\ui-storybook\stories\HibiscusAssets.stories.tsx",
    "apps\ui-storybook\stories\DraftActivityVisualReview.stories.tsx",
    "tools\visual-regression\playwright.config.ts"
)) {
    Add-File $relative
}

Log ""
Log "===== STORYBOOK + PLAYWRIGHT DISCOVERY ====="

$storyFiles = @(
    Get-ChildItem (Join-Path $root "apps\ui-storybook") -Recurse -File -Include *.ts,*.tsx -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch "\\node_modules\\" -and
        $_.FullName -notmatch "\\storybook-static\\"
    }
)

foreach ($needle in @(
    "Production Visual Baseline",
    "Assets/",
    "getAsset(",
    "screenshot",
    "viewport",
    "boundingBox",
    "toHaveScreenshot",
    "toBeVisible",
    "accessibility",
    "56"
)) {
    Log ""
    Log ("-- " + $needle + " --")

    $hits = @(
        @($storyFiles) +
        @(
            Get-ChildItem (Join-Path $root "tools\visual-regression") -Recurse -File -Include *.ts,*.tsx,*.js,*.mjs -ErrorAction SilentlyContinue
        ) |
        Select-String -SimpleMatch -Pattern $needle -ErrorAction SilentlyContinue
    )

    Log ("HITS: " + $hits.Count)

    foreach ($hit in $hits) {
        Log ($hit.Path.Substring($root.Length).TrimStart("\") + ":" + $hit.LineNumber + ": " + $hit.Line.Trim())
    }
}

Log ""
Log "===== MOJIBAKE / ENCODING SEARCH ====="

$encodingFiles = @(
    Get-ChildItem (Join-Path $root "apps") -Recurse -File -Include *.ts,*.tsx,*.json,*.md -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch "\\node_modules\\" -and
        $_.FullName -notmatch "\\storybook-static\\"
    }
)

foreach ($needle in @("Ã","Â","â","�")) {
    $hits = @($encodingFiles | Select-String -SimpleMatch -Pattern $needle -ErrorAction SilentlyContinue)
    Log ($needle + " | hits=" + $hits.Count)

    foreach ($hit in $hits) {
        Log ($hit.Path.Substring($root.Length).TrimStart("\") + ":" + $hit.LineNumber + ": " + $hit.Line.Trim())
    }
}

Log ""
Log "===== CLOSE-OUT REQUIREMENTS ====="
Log "1. Visual regression must cover all six production learning assets."
Log "2. Storybook must resolve every asset only through getAsset()."
Log "3. Desktop, tablet and mobile render checks should use the existing Playwright infrastructure."
Log "4. Runtime registry must expose WebP only for the six rich learning illustrations."
Log "5. Legacy SVGs must remain outside runtime-generated delivery paths."
Log "6. Asset metadata statuses should reflect the real reviewed/production state rather than stale legacy/review labels."
Log "7. Review/audit evidence must remain available after promotion."
Log "8. Mojibake must be corrected where still present."
Log "9. No activity manifest, curriculum sequence, mastery or learner progression rule should change."
Log "10. Close-out should establish the reusable governance gate for future rich raster assets."

Log ""
Log "PHASE 008R3A.6 PREFLIGHT: PASS"
Log "No production asset, manifest, registry or learner source was modified."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3A.6 PREFLIGHT: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
