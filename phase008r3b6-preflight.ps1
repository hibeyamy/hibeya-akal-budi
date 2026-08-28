Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3b6-preflight-" + $stamp)
$report = Join-Path $work "phase008r3b6-preflight.txt"
$zip = Join-Path $logs ("phase008r3b6-content-asset-integration-preflight-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Write-Log {
    param([string]$Text = "")
    Add-Content -Path $report -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Save-Zip {
    if (Test-Path $zip) {
        Remove-Item -Path $zip -Force -ErrorAction SilentlyContinue
    }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

function Capture-File {
    param([string]$Relative)

    $source = Join-Path $root $Relative
    if (Test-Path $source) {
        $safe = $Relative.Replace("\","__").Replace("/","__")
        Copy-Item -Path $source -Destination (Join-Path $work $safe) -Force
        Write-Log ("CAPTURED: " + $Relative)
    } else {
        Write-Log ("MISSING: " + $Relative)
    }
}

trap {
    Write-Log ""
    Write-Log "PHASE 008R3B.6 PREFLIGHT: FAILED"
    Write-Log ($_ | Out-String)
    Write-Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.6 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Production Activity Content + Asset Integration QA" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Write-Log ("Generated: " + (Get-Date).ToString("o"))
Write-Log ("Repository: " + $root)

$required = @(
    "tools\content-compiler\compile.mjs",
    "tools\assets\compile-commercial-registry.mjs",
    "packages\assets\src\generated\commercialRegistry.generated.ts",
    "packages\assets\source\raster-assets.json",
    "apps\learner-web\src\features\play\ActivityPlayer.tsx"
)

foreach ($relative in $required) {
    if (-not (Test-Path (Join-Path $root $relative))) {
        throw ("Required integration contract missing: " + $relative)
    }
}

Write-Log ""
Write-Log "===== CAPTURE RELEVANT CONTRACT FILES ====="

foreach ($relative in @(
    "tools\content-compiler\compile.mjs",
    "tools\assets\compile-commercial-registry.mjs",
    "packages\assets\src\index.ts",
    "packages\assets\src\metadata.ts",
    "packages\assets\src\generated\commercialRegistry.generated.ts",
    "packages\assets\source\raster-assets.json",
    "packages\assets\source\asset-migration.json",
    "packages\content-library\src\catalogue.ts",
    "packages\content-library\src\index.ts",
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "apps\learner-web\src\features\play\activityRegistry.ts",
    "apps\learner-web\src\features\play\ActivityPlayerAdapter.tsx",
    "apps\learner-web\src\journey\LearnerActivityBridge.tsx",
    "apps\learner-web\src\journey\LearnerJourneyScreen.tsx",
    "packages\offline\package.json",
    "apps\learner-web\package.json",
    "package.json"
)) {
    Capture-File $relative
}

Write-Log ""
Write-Log "===== ACTIVITY / ASSET REFERENCE MAP ====="

$searchRoots = @(
    (Join-Path $root "packages\content-library\src"),
    (Join-Path $root "apps\learner-web\src"),
    (Join-Path $root "packages\assets\src")
)

$searchFiles = @()
foreach ($searchRoot in $searchRoots) {
    if (-not (Test-Path $searchRoot)) { continue }

    $searchFiles += @(
        Get-ChildItem -Path $searchRoot -Recurse -File -Include *.ts,*.tsx,*.js,*.mjs,*.json -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\dist\\"
        }
    )
}

$assetIds = @(
    "apple-red",
    "apple-green",
    "banana-yellow",
    "hibiscus-red",
    "hibiscus-yellow",
    "hibiscus-purple"
)

foreach ($id in $assetIds) {
    Write-Log ""
    Write-Log ("-- " + $id + " --")

    $hits = @(
        $searchFiles |
        Select-String -SimpleMatch -Pattern $id -Context 2,5 -ErrorAction SilentlyContinue
    )

    Write-Log ("HITS: " + $hits.Count)

    foreach ($hit in $hits) {
        Write-Log $hit.ToString()
    }
}

Write-Log ""
Write-Log "===== PHYSICAL FORMAT LEAK SEARCH ====="

foreach ($needle in @(
    ".svg",
    ".png",
    ".webp",
    "source/review",
    "source/masters",
    "source/legacy",
    "src/generated"
)) {
    $hits = @(
        $searchFiles |
        Select-String -SimpleMatch -Pattern $needle -Context 1,4 -ErrorAction SilentlyContinue
    )

    Write-Log ""
    Write-Log ("-- " + $needle + " | hits=" + $hits.Count + " --")

    foreach ($hit in $hits) {
        Write-Log $hit.ToString()
    }
}

Write-Log ""
Write-Log "===== GETASSET / CORRECTNESS OWNERSHIP SEARCH ====="

foreach ($needle in @(
    "getAsset(",
    "correct:",
    "correctOption",
    "isCorrect",
    "submitAnswer(",
    "implementationKey",
    "options:",
    "asset:"
)) {
    $hits = @(
        $searchFiles |
        Select-String -SimpleMatch -Pattern $needle -Context 2,7 -ErrorAction SilentlyContinue
    )

    Write-Log ""
    Write-Log ("-- " + $needle + " | hits=" + $hits.Count + " --")

    foreach ($hit in $hits) {
        Write-Log $hit.ToString()
    }
}

Write-Log ""
Write-Log "===== OFFLINE / PWA ASSET DISCOVERY ====="

$offlineRoots = @(
    (Join-Path $root "packages\offline"),
    (Join-Path $root "apps\learner-web")
)

$offlineFiles = @()
foreach ($offlineRoot in $offlineRoots) {
    if (-not (Test-Path $offlineRoot)) { continue }

    $offlineFiles += @(
        Get-ChildItem -Path $offlineRoot -Recurse -File -Include *.ts,*.tsx,*.js,*.mjs,*.json -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\dist\\"
        }
    )
}

foreach ($needle in @(
    "serviceWorker",
    "registerSW",
    "workbox",
    "precache",
    "cache",
    "offline",
    "getAsset(",
    ".webp"
)) {
    $hits = @(
        $offlineFiles |
        Select-String -SimpleMatch -Pattern $needle -Context 2,6 -ErrorAction SilentlyContinue
    )

    Write-Log ""
    Write-Log ("-- " + $needle + " | hits=" + $hits.Count + " --")

    foreach ($hit in $hits) {
        Write-Log $hit.ToString()
    }
}

Write-Log ""
Write-Log "===== REPRODUCIBILITY / BUILD COMMAND DISCOVERY ====="

foreach ($relative in @("package.json","apps\learner-web\package.json")) {
    $full = Join-Path $root $relative
    if (-not (Test-Path $full)) { continue }

    $json = Get-Content -Path $full -Raw | ConvertFrom-Json
    Write-Log ("-- " + $relative + " --")

    $scriptsProperty = $json.PSObject.Properties["scripts"]
    if ($null -ne $scriptsProperty -and $null -ne $scriptsProperty.Value) {
        foreach ($property in $scriptsProperty.Value.PSObject.Properties) {
            Write-Log ($property.Name + " = " + $property.Value)
        }
    }
}

Write-Log ""
Write-Log "===== R3B.6 DECISION RULES ====="
Write-Log "1. Semantic asset IDs remain the only content-to-runtime visual contract."
Write-Log "2. Learner/content code must not hard-code .svg, .png or .webp delivery paths."
Write-Log "3. getAsset() remains the production resolver boundary."
Write-Log "4. Correctness remains activity/content/mechanic-owned, never asset-owned."
Write-Log "5. Review, master and legacy asset directories must not leak into learner runtime references."
Write-Log "6. Commercial registry output must remain deterministic."
Write-Log "7. Content compiler output must remain deterministic."
Write-Log "8. Production WebP derivatives must exist for governed rich illustrations."
Write-Log "9. Offline/PWA delivery must not depend on development-only Storybook paths."
Write-Log "10. Missing-asset handling should fail safely without silently selecting a different semantic asset."
Write-Log "11. No curriculum ordering, answer key, mastery threshold or progression rule may change."
Write-Log "12. No approved fruit or hibiscus artwork may be regenerated or visually altered."

Write-Log ""
Write-Log "PHASE 008R3B.6 PREFLIGHT: PASS"
Write-Log "No content, learner source, asset, dependency, manifest or lockfile was modified."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3B.6 PREFLIGHT: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
