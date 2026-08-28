Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs "phase008r3a4-preflight-$stamp"
$report = Join-Path $work "report.txt"
$zip = Join-Path $logs "phase008r3a4-raster-pipeline-preflight-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    [IO.File]::AppendAllText($report,$Text+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
    Write-Host $Text
}

function Get-Files([string]$Path,[string[]]$Includes) {
    if (-not (Test-Path $Path)) { return @() }
    return @(
        Get-ChildItem -Path $Path -Recurse -File -Include $Includes -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\node_modules\\' -and
            $_.FullName -notmatch '\\dist\\' -and
            $_.FullName -notmatch '\\storybook-static\\' -and
            $_.FullName -notmatch '\\test-results\\' -and
            $_.FullName -notmatch '\\playwright-report\\' -and
            $_.FullName -notmatch '\\\.git\\'
        }
    )
}

trap {
    Log ""
    Log "PHASE 008R3A.4 PREFLIGHT: FAILED"
    Log ($_ | Out-String)
    if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force -ErrorAction SilentlyContinue
    Write-Host "ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.4 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Raster Asset Pipeline Contract Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$assetRoot = Join-Path $root "packages\assets"
$masterDir = Join-Path $assetRoot "source\masters\flora"
$runtimeDir = Join-Path $assetRoot "src\generated"
$migration = Join-Path $assetRoot "source\asset-migration.json"
$metadata = Join-Path $assetRoot "src\metadata.ts"

foreach ($required in @($masterDir,$runtimeDir,$migration,$metadata)) {
    if (-not (Test-Path $required)) {
        throw "Phase 008R3A.3 contract missing: $required"
    }
}

$ids = @("hibiscus-red","hibiscus-yellow","hibiscus-purple")
Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Log ""
Log "MASTER / DERIVATIVE INVENTORY"

foreach ($id in $ids) {
    $png = Join-Path $masterDir "$id.png"
    $webp = Join-Path $runtimeDir "$id.webp"
    if (-not (Test-Path $png)) { throw "Master missing: $png" }
    if (-not (Test-Path $webp)) { throw "Runtime derivative missing: $webp" }

    $p = Get-Item $png
    $w = Get-Item $webp
    Log "$id"
    Log "  master: $($p.Length) bytes | sha256=$((Get-FileHash $png -Algorithm SHA256).Hash)"
    Log "  runtime: $($w.Length) bytes | sha256=$((Get-FileHash $webp -Algorithm SHA256).Hash)"
    Log ("  compression-ratio: {0:N3}" -f ($w.Length / [double]$p.Length))
}

Log ""
Log "AVAILABLE IMAGE TOOLING"

$commands = @(
    "magick",
    "convert",
    "cwebp",
    "ffmpeg",
    "sharp"
)

foreach ($name in $commands) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
        Log "$name = $($cmd.Source)"
    } else {
        Log "$name = NOT FOUND"
    }
}

Log ""
Log "NODE IMAGE DEPENDENCIES"

$packageFiles = @(Get-Files $root @("package.json"))
foreach ($pkg in $packageFiles) {
    $text = Get-Content $pkg.FullName -Raw
    foreach ($needle in @("sharp","@squoosh","imagemin","webp","image-size")) {
        if ($text -match [Regex]::Escape($needle)) {
            Log "$($pkg.FullName.Substring($root.Length).TrimStart("\")) contains $needle"
        }
    }
}

Log ""
Log "CURRENT ASSET GENERATION / COMPILER REFERENCES"
$codeFiles = @(
    (Get-Files (Join-Path $root "packages") @("*.ts","*.tsx","*.js","*.mjs","*.cjs","*.json")) +
    (Get-Files (Join-Path $root "tools") @("*.ts","*.js","*.mjs","*.cjs","*.json"))
)
foreach ($needle in @(
    "commercialRegistry.generated",
    "generatedCommercialAssetOverrides",
    "sharp(",
    ".webp",
    "source/masters",
    "asset-migration.json",
    "quality",
    "lossless",
    "resize"
)) {
    $hits = @($codeFiles | Select-String -SimpleMatch -Pattern $needle -ErrorAction SilentlyContinue)
    Log "$needle | hits=$($hits.Count)"
    foreach ($hit in $hits) {
        Log ("  {0}:{1}: {2}" -f $hit.Path.Substring($root.Length).TrimStart("\"),$hit.LineNumber,$hit.Line.Trim())
    }
}

Log ""
Log "PIPELINE REQUIREMENTS TO IMPLEMENT"
Log "1. PNG master is immutable input; WebP is reproducible derivative."
Log "2. Semantic IDs and curriculum manifests remain format-agnostic."
Log "3. Build must fail for missing master, invalid dimensions, excessive file size or stale derivative."
Log "4. Generation must be deterministic enough for repository reproducibility checks."
Log "5. Runtime derivative should preserve transparency."
Log "6. Rich illustrations should not be bundled as base64 or embedded into JavaScript."
Log "7. Compiler-owned generated registry must remain generated, not manually curated."
Log "8. Fruit migration remains deferred until approved raster masters exist."
Log "9. No new image dependency will be chosen until this preflight identifies existing repository/tooling constraints."
Log "10. This preflight performs no conversion, dependency installation, artwork edit or manifest change."

Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
Write-Host ""
Write-Host "PASS: Phase 008R3A.4 raster-pipeline preflight" -ForegroundColor Green
Write-Host "ZIP: $zip" -ForegroundColor Cyan
Write-Host "No repository file was modified." -ForegroundColor Cyan
