Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs "phase008r3a3-legacy-asset-migration-$stamp"
$log = Join-Path $work "phase008r3a3.log"
$zip = Join-Path $logs "phase008r3a3-legacy-asset-migration-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    [IO.File]::AppendAllText(
        $log,
        $Text + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
    Write-Host $Text
}

function Backup([string]$RelativePath) {
    $source = Join-Path $root $RelativePath
    if (-not (Test-Path $source)) { return }

    $safe = $RelativePath -replace '[\\/:*?"<>|]', '_'
    Copy-Item $source (Join-Path $backups "$stamp-$safe") -Force
}

function Write-Utf8([string]$Path,[string]$Content) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    [IO.File]::WriteAllText(
        $Path,
        $Content.TrimEnd() + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
}

function Run-Native([string]$Label,[string]$Command) {
    Log ""
    Log "==> $Label"
    Log $Command

    $stdout = Join-Path $work ("stdout-" + [Guid]::NewGuid().ToString("N") + ".txt")
    $stderr = Join-Path $work ("stderr-" + [Guid]::NewGuid().ToString("N") + ".txt")

    $process = Start-Process `
        -FilePath "cmd.exe" `
        -ArgumentList @("/d","/s","/c",$Command) `
        -WorkingDirectory $root `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr

    foreach ($path in @($stdout,$stderr)) {
        if (Test-Path $path) {
            $text = Get-Content $path -Raw -ErrorAction SilentlyContinue
            if ($text) {
                [IO.File]::AppendAllText(
                    $log,
                    $text.TrimEnd() + [Environment]::NewLine,
                    [Text.UTF8Encoding]::new($false)
                )
                Write-Host $text.TrimEnd()
            }
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        }
    }

    if ($process.ExitCode -ne 0) {
        throw "$Label failed with exit code $($process.ExitCode)."
    }

    Log "PASS: $Label"
}

function Zip-Log {
    if (Test-Path $zip) {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }

    Compress-Archive `
        -Path (Join-Path $work "*") `
        -DestinationPath $zip `
        -Force
}

trap {
    Log ""
    Log "PHASE 008R3A.3: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace

    Zip-Log

    Write-Host ""
    Write-Host "PHASE 008R3A.3: FAILED" -ForegroundColor Red
    Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Set-Location $root

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.3" -ForegroundColor Cyan
Write-Host "Legacy Asset Migration" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

$generatedDir = Join-Path $root "packages\assets\src\generated"
$masterDir = Join-Path $root "packages\assets\source\masters\flora"
$legacyDir = Join-Path $root "packages\assets\source\legacy\flora"
$metadataPath = Join-Path $root "packages\assets\src\metadata.ts"
$registryPath = Join-Path $root "packages\assets\src\generated\commercialRegistry.generated.ts"

foreach ($required in @(
    $generatedDir,
    $metadataPath,
    $registryPath
)) {
    if (-not (Test-Path $required)) {
        throw "Required asset migration contract missing: $required"
    }
}

$ids = @(
    "hibiscus-red",
    "hibiscus-yellow",
    "hibiscus-purple"
)

$fruitSvg = @(
    "apple-red.svg",
    "apple-green.svg",
    "banana-yellow.svg"
)

$registry = Get-Content $registryPath -Raw

foreach ($fruit in $fruitSvg) {
    if ($registry -notmatch [Regex]::Escape("./$fruit")) {
        throw "Fruit SVG runtime dependency drifted: $fruit"
    }
}

foreach ($id in $ids) {
    if ($registry -notmatch [Regex]::Escape("./$id.webp")) {
        throw "Hibiscus WebP runtime dependency drifted: $id.webp"
    }
}

Write-Host "PASS: exact runtime dependency contract verified" -ForegroundColor Green
Write-Host "PASS: fruit SVGs remain runtime dependencies and will not be moved" -ForegroundColor Green
Write-Host "PASS: hibiscus WebPs remain runtime derivatives and will not be moved" -ForegroundColor Green

New-Item -ItemType Directory -Force -Path $masterDir,$legacyDir | Out-Null

$manifestRows = @()

foreach ($id in $ids) {
    $pngSource = Join-Path $generatedDir "$id.png"
    $svgSource = Join-Path $generatedDir "$id.svg"
    $webpRuntime = Join-Path $generatedDir "$id.webp"

    foreach ($required in @($pngSource,$svgSource,$webpRuntime)) {
        if (-not (Test-Path $required)) {
            throw "Expected hibiscus migration file missing: $required"
        }
    }

    Backup "packages\assets\src\generated\$id.png"
    Backup "packages\assets\src\generated\$id.svg"

    $masterTarget = Join-Path $masterDir "$id.png"
    $legacyTarget = Join-Path $legacyDir "$id.svg"

    if (Test-Path $masterTarget) {
        throw "Master target already exists: $masterTarget"
    }

    if (Test-Path $legacyTarget) {
        throw "Legacy target already exists: $legacyTarget"
    }

    $pngHashBefore = (Get-FileHash $pngSource -Algorithm SHA256).Hash
    $svgHashBefore = (Get-FileHash $svgSource -Algorithm SHA256).Hash

    Copy-Item $pngSource $masterTarget -Force
    Copy-Item $svgSource $legacyTarget -Force

    $pngHashAfter = (Get-FileHash $masterTarget -Algorithm SHA256).Hash
    $svgHashAfter = (Get-FileHash $legacyTarget -Algorithm SHA256).Hash

    if ($pngHashBefore -ne $pngHashAfter) {
        throw "PNG master checksum mismatch for $id"
    }

    if ($svgHashBefore -ne $svgHashAfter) {
        throw "Legacy SVG checksum mismatch for $id"
    }

    Remove-Item $pngSource -Force
    Remove-Item $svgSource -Force

    $manifestRows += [PSCustomObject]@{
        id = $id
        master = "source/masters/flora/$id.png"
        runtime = "src/generated/$id.webp"
        legacy = "source/legacy/flora/$id.svg"
        masterSha256 = $pngHashAfter
        legacySha256 = $svgHashAfter
        runtimeSha256 = (Get-FileHash $webpRuntime -Algorithm SHA256).Hash
    }

    Write-Host "PASS: migrated $id PNG master and archived SVG prototype" -ForegroundColor Green
}

# Write an explicit migration inventory for governance.
$migrationManifest = [PSCustomObject]@{
    version = 1
    migratedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    policy = @{
        semanticIdsStable = $true
        runtimeDelivery = "webp"
        sourceMaster = "png"
        legacyPrototype = "svg"
        fruitSvgMigrationDeferred = $true
    }
    assets = $manifestRows
}

$migrationManifestPath = Join-Path $root "packages\assets\source\asset-migration.json"
$migrationManifest |
    ConvertTo-Json -Depth 8 |
    Set-Content -Path $migrationManifestPath -Encoding UTF8

# Add source/runtime paths to governance metadata without changing semantic IDs.
Backup "packages\assets\src\metadata.ts"
$metadata = Get-Content $metadataPath -Raw

if ($metadata -notmatch "sourcePath\?:") {
    $metadata = $metadata.Replace(
@'
  richIllustration: boolean;
  notes?: string;
'@,
@'
  richIllustration: boolean;
  sourcePath?: string;
  deliveryPath?: string;
  legacyPath?: string;
  notes?: string;
'@
    )
}

foreach ($id in $ids) {
    $needle = @"
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true
"@

    $replacement = @"
      sourceFormat: "png",
      deliveryFormat: "webp",
      richIllustration: true,
      sourcePath: "source/masters/flora/$id.png",
      deliveryPath: "src/generated/$id.webp",
      legacyPath: "source/legacy/flora/$id.svg"
"@

    $position = $metadata.IndexOf($needle)
    if ($position -lt 0) {
        throw "Could not locate hibiscus metadata format block for $id"
    }

    # Replace the first matching block after the current asset ID.
    $idPosition = $metadata.IndexOf('"' + $id + '"')
    if ($idPosition -lt 0) {
        throw "Could not locate metadata asset ID: $id"
    }

    $blockPosition = $metadata.IndexOf($needle,$idPosition)
    if ($blockPosition -lt 0) {
        throw "Could not locate metadata format block after asset ID: $id"
    }

    $metadata =
        $metadata.Substring(0,$blockPosition) +
        $replacement +
        $metadata.Substring($blockPosition + $needle.Length)
}

Write-Utf8 $metadataPath $metadata

# Safety assertions after migration.
foreach ($id in $ids) {
    if (Test-Path (Join-Path $generatedDir "$id.png")) {
        throw "PNG master still exists in generated/: $id.png"
    }

    if (Test-Path (Join-Path $generatedDir "$id.svg")) {
        throw "Legacy SVG still exists in generated/: $id.svg"
    }

    if (-not (Test-Path (Join-Path $generatedDir "$id.webp"))) {
        throw "Runtime WebP was accidentally moved or deleted: $id.webp"
    }

    if (-not (Test-Path (Join-Path $masterDir "$id.png"))) {
        throw "Migrated PNG master missing: $id.png"
    }

    if (-not (Test-Path (Join-Path $legacyDir "$id.svg"))) {
        throw "Archived legacy SVG missing: $id.svg"
    }
}

foreach ($fruit in $fruitSvg) {
    if (-not (Test-Path (Join-Path $generatedDir $fruit))) {
        throw "Fruit SVG was unexpectedly moved: $fruit"
    }
}

$registryAfter = Get-Content $registryPath -Raw
if ($registryAfter -match '\.png' -or $registryAfter -match 'hibiscus-(red|yellow|purple)\.svg') {
    throw "Commercial registry unexpectedly references migrated hibiscus source/legacy files."
}

Log "PASS: semantic IDs remain unchanged"
Log "PASS: hibiscus runtime WebPs remain compiler/runtime-owned"
Log "PASS: PNG masters now live under source/masters/flora"
Log "PASS: old hibiscus SVG prototypes are archived under source/legacy/flora"
Log "PASS: fruit SVG runtime dependencies remain untouched"

Run-Native "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run-Native "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run-Native "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run-Native "Learner web tests" "pnpm --filter learner-web test"
Run-Native "Storybook production build" "pnpm --filter ui-storybook build-storybook"
Run-Native "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run-Native "Frozen lockfile verification" "pnpm install --frozen-lockfile"
Run-Native "Git whitespace check" "git diff --check"

Log ""
Log "PHASE 008R3A.3: PASS"
Log "Next: Phase 008R3A.4 Raster Asset Pipeline"
Log "No semantic asset ID, activity manifest, curriculum rule, approval flag, or learner progression rule changed."

Zip-Log

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008R3A.3: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Hibiscus source/runtime separation is now explicit." -ForegroundColor Cyan
Write-Host "Fruit SVG migration remains intentionally deferred." -ForegroundColor Cyan
Write-Host "Diagnostic ZIP: $zip" -ForegroundColor White
