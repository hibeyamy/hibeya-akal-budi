Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3a5c-preflight-" + $stamp)
$report = Join-Path $work "phase008r3a5c-preflight.txt"
$zip = Join-Path $logs ("phase008r3a5c-controlled-promotion-preflight-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Add-FileEvidence([string]$RelativePath) {
    $full = Join-Path $root $RelativePath
    Log ""
    Log ("===== FILE: " + $RelativePath + " =====")
    if (-not (Test-Path $full)) {
        Log "STATUS: NOT FOUND"
        return
    }
    $item = Get-Item $full
    Log ("SIZE: " + $item.Length + " bytes")
    Log ("SHA256: " + (Get-FileHash $full -Algorithm SHA256).Hash)
    Log "CONTENT:"
    Get-Content -Path $full -ErrorAction SilentlyContinue | ForEach-Object { Log $_ }
}

function Save-Zip {
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

trap {
    Log ""
    Log "PHASE 008R3A.5C PREFLIGHT: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ""
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.5C PREFLIGHT" -ForegroundColor Cyan
Write-Host "Controlled Fruit Promotion Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log ("Generated: " + (Get-Date).ToString("o"))
Log ("Repository: " + $root)

$ids = @("apple-red","apple-green","banana-yellow")
$reviewDir = Join-Path $root "packages\assets\source\review\fruit"

Log ""
Log "===== REVIEWED CANDIDATES ====="
foreach ($id in $ids) {
    $png = Join-Path $reviewDir ($id + ".png")
    $json = Join-Path $reviewDir ($id + ".review.json")

    if (-not (Test-Path $png)) { throw ("Missing reviewed PNG: " + $png) }
    if (-not (Test-Path $json)) { throw ("Missing review record: " + $json) }

    $record = Get-Content -Path $json -Raw | ConvertFrom-Json
    if ($record.visualReviewed -ne $true) {
        throw ("visualReviewed is not true for " + $id)
    }
    if ($record.productionEnabled -eq $true) {
        throw ("Candidate is already production-enabled: " + $id)
    }

    Log ($id + " | PNG=" + (Get-Item $png).Length + " bytes | SHA256=" + (Get-FileHash $png -Algorithm SHA256).Hash)
    Log ($id + " | visualReviewed=true | productionEnabled=false")
}

Log ""
Log "===== CURRENT FRUIT PHYSICAL FILES ====="
foreach ($id in $ids) {
    Log ("-- " + $id + " --")
    $hits = @(Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match ("^" + [Regex]::Escape($id) + "\.(svg|png|webp|avif)$") -and
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\\.git\\" -and
            $_.FullName -notmatch "\\storybook-static\\"
        })
    if ($hits.Count -eq 0) { Log "NONE" }
    foreach ($hit in $hits) {
        Log ($hit.FullName.Substring($root.Length).TrimStart("\") + " | " + $hit.Length + " bytes")
    }
}

Log ""
Log "===== ACTIVE FRUIT REFERENCES ====="
$searchRoots = @(
    (Join-Path $root "packages"),
    (Join-Path $root "apps"),
    (Join-Path $root "tools")
)
$extensions = @("*.ts","*.tsx","*.js","*.mjs","*.json","*.md","*.css")
foreach ($id in $ids) {
    Log ("-- " + $id + " --")
    $count = 0
    foreach ($searchRoot in $searchRoots) {
        if (-not (Test-Path $searchRoot)) { continue }
        $files = @(Get-ChildItem $searchRoot -Recurse -File -Include $extensions -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch "\\node_modules\\" -and
                $_.FullName -notmatch "\\dist\\" -and
                $_.FullName -notmatch "\\storybook-static\\"
            })
        foreach ($file in $files) {
            $matches = @(Select-String -Path $file.FullName -SimpleMatch -Pattern $id -ErrorAction SilentlyContinue)
            foreach ($match in $matches) {
                $count++
                Log ($file.FullName.Substring($root.Length).TrimStart("\") + ":" + $match.LineNumber + ": " + $match.Line.Trim())
            }
        }
    }
    Log ("REFERENCE COUNT: " + $count)
}

Log ""
Log "===== RELEVANT CONTRACT FILES ====="
$contractFiles = @(
    "packages\assets\source\raster-assets.json",
    "packages\assets\source\visual-replacement-plan.json",
    "tools\assets\build-raster-assets.mjs",
    "tools\assets\compile-commercial-registry.mjs",
    "packages\assets\src\generated\commercialRegistry.generated.ts",
    "packages\assets\src\metadata.ts",
    "packages\assets\src\index.ts"
)
foreach ($file in $contractFiles) {
    Add-FileEvidence $file
}

Log ""
Log "===== ASSET PACKAGE TREE ====="
$assetRoot = Join-Path $root "packages\assets"
Get-ChildItem $assetRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch "\\node_modules\\" -and
        $_.FullName -notmatch "\\dist\\"
    } |
    Sort-Object FullName |
    ForEach-Object {
        Log ($_.FullName.Substring($root.Length).TrimStart("\") + " | " + $_.Length + " bytes")
    }

Log ""
Log "===== PROMOTION SAFETY DECISION ====="
Log "1. Preflight is read-only except for this diagnostic ZIP."
Log "2. Reviewed PNG candidates must remain unchanged during inspection."
Log "3. Promotion must preserve semantic IDs."
Log "4. Promotion must copy reviewed PNGs to authoritative master paths before derivative generation."
Log "5. raster-assets.json must become the explicit production source of truth for fruit derivatives."
Log "6. Runtime registry must switch only after WebP generation succeeds."
Log "7. Legacy SVG deletion is forbidden until zero active runtime references are proven."
Log "8. Curriculum, activity manifests, mastery, progression and sequencing must remain unchanged."
Log "9. Review records must retain audit evidence after promotion."
Log "10. Promotion implementation must be generated from this observed repository state."

Log ""
Log "PHASE 008R3A.5C PREFLIGHT: PASS"
Log "No production asset, registry, manifest or runtime source was modified."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3A.5C PREFLIGHT: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
