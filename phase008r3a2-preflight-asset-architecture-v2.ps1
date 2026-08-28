Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$workDir = Join-Path $logs "phase008r3a2-asset-architecture-preflight-$stamp"
$report = Join-Path $workDir "report.txt"
$zip = Join-Path $logs "phase008r3a2-asset-architecture-preflight-$stamp.zip"

New-Item -ItemType Directory -Force -Path $workDir | Out-Null

function Add-Line([string]$Text = "") {
    Add-Content -Path $report -Value $Text -Encoding UTF8
}

function Get-SourceFiles([string]$Path,[string[]]$Includes) {
    if (-not (Test-Path $Path)) { return @() }

    return @(
        Get-ChildItem -Path $Path -Recurse -File -Include $Includes -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\node_modules\\' -and
            $_.FullName -notmatch '\\dist\\' -and
            $_.FullName -notmatch '\\storybook-static\\' -and
            $_.FullName -notmatch '\\test-results\\' -and
            $_.FullName -notmatch '\\playwright-report\\' -and
            $_.FullName -notmatch '\\\.turbo\\' -and
            $_.FullName -notmatch '\\\.git\\'
        }
    )
}

function Search-Files([object[]]$Files,[string[]]$Patterns,[string]$Section) {
    Add-Line ""
    Add-Line "===================================================="
    Add-Line $Section
    Add-Line "===================================================="

    foreach ($pattern in $Patterns) {
        Add-Line ""
        Add-Line "---- PATTERN: $pattern ----"

        $hits = @(
            @($Files) |
            Select-String -Pattern $pattern -SimpleMatch -Context 2,8 -ErrorAction SilentlyContinue
        )

        if ($hits.Count -eq 0) {
            Add-Line "[NO MATCHES]"
        }
        else {
            foreach ($hit in $hits) {
                $hit.ToString() | Add-Content -Path $report -Encoding UTF8
            }
        }
    }
}

function Snapshot([string]$RelativePath) {
    $full = Join-Path $root $RelativePath
    $snapshots = Join-Path $workDir "snapshots"
    New-Item -ItemType Directory -Force -Path $snapshots | Out-Null
    $safe = $RelativePath -replace '[\\/:*?"<>|]', '_'
    $target = Join-Path $snapshots $safe

    Add-Line ""
    Add-Line "===================================================="
    Add-Line "FILE: $RelativePath"
    Add-Line "===================================================="

    if (Test-Path $full) {
        Copy-Item $full $target -Force
        Get-Content $full -ErrorAction Stop | Add-Content -Path $report -Encoding UTF8
    }
    else {
        Add-Line "[MISSING]"
    }
}

trap {
    Add-Line ""
    Add-Line "PHASE 008R3A.2 PREFLIGHT: FAILED"
    Add-Line ($_ | Out-String)
    Add-Line $_.ScriptStackTrace

    if (Test-Path $zip) {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $workDir) {
        Compress-Archive -Path (Join-Path $workDir "*") -DestinationPath $zip -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "PHASE 008R3A.2 PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.2 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Asset Architecture Foundation Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Add-Line "HIBEYA AKAL BUDI - PHASE 008R3A.2 PREFLIGHT"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Add-Line "Purpose: derive a scalable source/master/delivery/metadata asset architecture from the current repository."

$assetRoot = Join-Path $root "packages\assets"
if (-not (Test-Path $assetRoot)) {
    throw "Asset package missing: $assetRoot"
}

$assetFiles = @(Get-SourceFiles $assetRoot @("*.ts","*.tsx","*.json","*.svg","*.png","*.jpg","*.jpeg","*.webp","*.avif"))
$storybookFiles = @(Get-SourceFiles (Join-Path $root "apps\ui-storybook") @("*.ts","*.tsx","*.js","*.json"))
$learnerFiles = @(Get-SourceFiles (Join-Path $root "apps\learner-web\src") @("*.ts","*.tsx","*.json"))
$compilerFiles = @(Get-SourceFiles (Join-Path $root "tools\content-compiler") @("*.mjs","*.cjs","*.ts","*.json"))
$allFiles = @($assetFiles + $storybookFiles + $learnerFiles + $compilerFiles)

Write-Host "PASS: bounded asset/runtime scopes collected ($($allFiles.Count) files)" -ForegroundColor Green

foreach ($relative in @(
    "packages\assets\package.json",
    "packages\assets\tsconfig.json",
    "packages\assets\src\index.ts",
    "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx",
    "apps\ui-storybook\stories\HibiscusAssets.stories.tsx",
    "apps\learner-web\src\features\play\ActivityPlayer.tsx",
    "tools\content-compiler\compile.mjs",
    "package.json"
)) {
    Snapshot $relative
}

Search-Files @($assetFiles) @(
    "export type",
    "export interface",
    "AssetId",
    "getAsset",
    "assetRegistry",
    "generated",
    "src/generated",
    ".webp",
    ".png",
    ".svg",
    "alt:",
    "type:",
    "value:",
    "width",
    "height"
) "CURRENT ASSET PACKAGE CONTRACT"

Search-Files @($assetFiles + $learnerFiles + $storybookFiles) @(
    "import.meta.glob",
    "new URL(",
    "?url",
    "public/",
    "src=",
    "getAsset(",
    "asset.value",
    "asset.type",
    "image"
) "ASSET DELIVERY / BUNDLER CONTRACT"

Search-Files @($assetFiles + $storybookFiles) @(
    "provenance",
    "version",
    "approved",
    "reviewed",
    "creator",
    "sourceFormat",
    "deliveryFormat",
    "transparent",
    "visualFamily",
    "status",
    "legacy"
) "ASSET GOVERNANCE / METADATA SEARCH"

Search-Files @($assetFiles + $storybookFiles + $learnerFiles) @(
    "apple-red",
    "apple-green",
    "banana-yellow",
    "hibiscus-red",
    "hibiscus-yellow",
    "hibiscus-purple"
) "SIX-LEGACY-ASSET REFERENCE SEARCH"

Add-Line ""
Add-Line "===================================================="
Add-Line "ASSET FILE INVENTORY"
Add-Line "===================================================="

$inventory = @()

foreach ($file in ($assetFiles | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($root.Length).TrimStart("\")
    $ext = $file.Extension.ToLowerInvariant()

    $inventory += [PSCustomObject]@{
        Path = $relative
        Extension = $ext
        Bytes = $file.Length
    }

    Add-Line ("{0} | {1} | {2} bytes" -f $relative,$ext,$file.Length)
}

Add-Line ""
Add-Line "===================================================="
Add-Line "FORMAT COUNTS"
Add-Line "===================================================="

foreach ($group in ($inventory | Group-Object Extension | Sort-Object Name)) {
    Add-Line ("Extension={0} | Count={1} | Bytes={2}" -f
        $group.Name,
        $group.Count,
        (($group.Group | Measure-Object Bytes -Sum).Sum)
    )
}

Add-Line ""
Add-Line "===================================================="
Add-Line "PHASE 008R3A.2 IMPLEMENTATION DECISIONS"
Add-Line "===================================================="
Add-Line "1. Keep semantic asset IDs stable across artwork replacements."
Add-Line "2. Separate authoritative source/master assets from runtime delivery assets."
Add-Line "3. Prefer WebP for rich learning illustrations; retain PNG masters where lossless transparency/source quality is needed."
Add-Line "4. Keep SVG for simple UI/iconography only, not as the default rich illustration format."
Add-Line "5. Introduce asset metadata for status/version/provenance/review/visual-family."
Add-Line "6. Do not change current artwork appearance in the foundation phase."
Add-Line "7. Do not change activity manifests in the foundation phase."
Add-Line "8. Do not remove legacy files until migration proves replacement references."
Add-Line "9. Ensure future runtime can load only assets required by the current activity."
Add-Line "10. Preserve PWA/offline compatibility and existing semantic getAsset() consumers."

$summaryPath = Join-Path $workDir "asset-architecture-summary.json"

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    totalAssetFiles = $assetFiles.Count
    formats = @(
        $inventory |
        Group-Object Extension |
        Sort-Object Name |
        ForEach-Object {
            @{
                extension = $_.Name
                count = $_.Count
                totalBytes = (($_.Group | Measure-Object Bytes -Sum).Sum)
            }
        }
    )
    intendedDirection = @{
        semanticIdsStable = $true
        richIllustrationDelivery = "webp"
        losslessSourceMaster = "png-when-needed"
        simpleUiIconography = "svg"
        metadataGovernance = $true
        sourceRuntimeSeparation = $true
        noArtworkChangeInFoundation = $true
    }
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryPath -Encoding UTF8

if (Test-Path $zip) {
    Remove-Item $zip -Force
}

Compress-Archive -Path (Join-Path $workDir "*") -DestinationPath $zip -Force

if (-not (Test-Path $zip)) {
    throw "Preflight ZIP was not created."
}

Write-Host ""
Write-Host "PASS: Phase 008R3A.2 asset-architecture preflight ZIP created" -ForegroundColor Green
Write-Host "ZIP:" -ForegroundColor Cyan
Write-Host "  $zip" -ForegroundColor White
Write-Host ""
Write-Host "No asset, source, manifest, generated catalogue, review flag, dependency, or lockfile was modified." -ForegroundColor Cyan
