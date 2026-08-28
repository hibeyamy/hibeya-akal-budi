Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$workDir = Join-Path $logs "phase008r3a1-asset-audit-preflight-$stamp"
$report = Join-Path $workDir "report.txt"
$zip = Join-Path $logs "phase008r3a1-asset-audit-preflight-$stamp.zip"

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
        } else {
            foreach ($hit in $hits) {
                $hit.ToString() | Add-Content -Path $report -Encoding UTF8
            }
        }
    }
}

trap {
    Add-Line ""
    Add-Line "PHASE 008R3A.1 PREFLIGHT: FAILED"
    Add-Line ($_ | Out-String)
    Add-Line $_.ScriptStackTrace

    if (Test-Path $zip) {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $workDir) {
        Compress-Archive -Path (Join-Path $workDir "*") -DestinationPath $zip -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "PHASE 008R3A.1 PREFLIGHT: FAILED" -ForegroundColor Red
    Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.1 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Asset Provenance + Dependency Audit" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Add-Line "HIBEYA AKAL BUDI - PHASE 008R3A.1 PREFLIGHT"
Add-Line "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

$assetRoot = Join-Path $root "packages\assets"
$manifestRoot = Join-Path $root "content\activity-manifests"

foreach ($required in @($assetRoot,$manifestRoot,(Join-Path $root "apps\ui-storybook"))) {
    if (-not (Test-Path $required)) {
        throw "Required repository scope missing: $required"
    }
}

$assetFiles = @(Get-SourceFiles $assetRoot @("*.ts","*.tsx","*.json","*.svg","*.png","*.jpg","*.jpeg","*.webp"))
$manifestFiles = @(Get-ChildItem $manifestRoot -File -Filter *.json -ErrorAction SilentlyContinue)
$storybookFiles = @(Get-SourceFiles (Join-Path $root "apps\ui-storybook") @("*.ts","*.tsx","*.js","*.mjs","*.cjs","*.json"))
$learnerFiles = @(Get-SourceFiles (Join-Path $root "apps\learner-web\src") @("*.ts","*.tsx","*.json"))
$compilerFiles = @(Get-SourceFiles (Join-Path $root "tools\content-compiler") @("*.mjs","*.cjs","*.ts","*.json"))

$allFiles = @($assetFiles + $manifestFiles + $storybookFiles + $learnerFiles + $compilerFiles)

Write-Host "PASS: bounded asset/dependency scopes collected ($($allFiles.Count) files)" -ForegroundColor Green

$assetIds = @(
    "apple-red",
    "apple-green",
    "banana-yellow",
    "hibiscus-red",
    "hibiscus-yellow",
    "hibiscus-purple"
)

Add-Line ""
Add-Line "===================================================="
Add-Line "ASSET REFERENCE MATRIX"
Add-Line "===================================================="

$matrix = @()

foreach ($assetId in $assetIds) {
    $refs = @(
        $allFiles |
        Select-String -Pattern $assetId -SimpleMatch -ErrorAction SilentlyContinue
    )

    $refFiles = @(
        $refs |
        ForEach-Object { $_.Path } |
        Sort-Object -Unique
    )

    $matrix += [PSCustomObject]@{
        AssetId = $assetId
        ReferenceCount = $refs.Count
        ReferenceFiles = $refFiles
    }

    Add-Line ("Asset={0} | References={1} | RefFiles={2}" -f $assetId,$refs.Count,$refFiles.Count)

    foreach ($file in $refFiles) {
        Add-Line ("  REF: " + $file.Substring($root.Length).TrimStart("\"))
    }
}

Search-Files @($assetFiles + $storybookFiles + $learnerFiles) @(
    "getAsset(",
    "assetRegistry",
    "apple-red",
    "apple-green",
    "banana-yellow",
    "hibiscus-red",
    "hibiscus-yellow",
    "hibiscus-purple"
) "ASSET REGISTRY / CONSUMER SEARCH"

Search-Files @($assetFiles + $storybookFiles) @(
    "<svg",
    ".svg",
    "data:image/svg",
    "generated",
    "original",
    "provenance",
    "review",
    "legacy",
    "placeholder"
) "ASSET IMPLEMENTATION / PROVENANCE SEARCH"

Search-Files @($storybookFiles + $learnerFiles + $compilerFiles) @(
    "Production Visual Baseline",
    "Ã",
    "â",
    "Â",
    "�",
    "HIBEYA Akal Budi"
) "TEXT ENCODING / MOJIBAKE SEARCH"

Add-Line ""
Add-Line "===================================================="
Add-Line "MANIFEST ASSET DEPENDENCIES"
Add-Line "===================================================="

foreach ($manifestFile in ($manifestFiles | Sort-Object Name)) {
    try {
        $manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json
        $activityId = if ($manifest.activity.id) { [string]$manifest.activity.id } else { $manifestFile.BaseName }

        $assets = @()
        if ($manifest.activity.options) {
            $assets = @(
                @($manifest.activity.options) |
                Where-Object { $_.asset } |
                ForEach-Object { [string]$_.asset } |
                Sort-Object -Unique
            )
        }

        Add-Line ("Activity={0} | Assets={1}" -f $activityId,($assets -join ","))
    }
    catch {
        Add-Line "MANIFEST_PARSE_ERROR: $($manifestFile.Name)"
    }
}

Add-Line ""
Add-Line "===================================================="
Add-Line "PHASE 008R3A.1 DECISION QUESTIONS"
Add-Line "===================================================="
Add-Line "1. Which of the six current asset IDs are referenced by production or governed draft content?"
Add-Line "2. Which asset IDs exist only for Storybook/audit/demo purposes?"
Add-Line "3. Can underlying artwork be replaced behind stable semantic IDs without touching manifests?"
Add-Line "4. Are SVGs inline/generated, file-backed, or registry constants?"
Add-Line "5. Which source files can be removed safely after replacement?"
Add-Line "6. Are apple/banana assets unused enough to retire?"
Add-Line "7. Which stories/tests would need updating if those assets are removed?"
Add-Line "8. Where exactly is mojibake introduced?"
Add-Line "9. Do not delete or replace any asset in this preflight."
Add-Line "10. Do not promote beza-bunga-raya-001 until the approved artwork strategy is confirmed."

$summaryPath = Join-Path $workDir "asset-audit-summary.json"

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    assets = @(
        $matrix | ForEach-Object {
            @{
                assetId = $_.AssetId
                referenceCount = $_.ReferenceCount
                referenceFiles = @(
                    $_.ReferenceFiles | ForEach-Object {
                        $_.Substring($root.Length).TrimStart("\")
                    }
                )
            }
        }
    )
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryPath -Encoding UTF8

$inventoryPath = Join-Path $workDir "asset-file-inventory.txt"
foreach ($file in ($assetFiles | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($root.Length).TrimStart("\")
    "$relative | $($file.Length) bytes" | Add-Content -Path $inventoryPath -Encoding UTF8
}

if (Test-Path $zip) {
    Remove-Item $zip -Force
}

Compress-Archive -Path (Join-Path $workDir "*") -DestinationPath $zip -Force

if (-not (Test-Path $zip)) {
    throw "Asset-audit ZIP was not created."
}

Write-Host ""
Write-Host "PASS: Phase 008R3A.1 asset-audit preflight ZIP created" -ForegroundColor Green
Write-Host "ZIP:" -ForegroundColor Cyan
Write-Host "  $zip" -ForegroundColor White
Write-Host ""
Write-Host "No asset, source, manifest, generated catalogue, review flag, dependency, or lockfile was modified." -ForegroundColor Cyan
