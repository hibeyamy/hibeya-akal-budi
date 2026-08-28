Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs "phase008r3a3-preflight-$stamp"
$report = Join-Path $work "report.txt"
$zip = Join-Path $logs "phase008r3a3-legacy-asset-migration-preflight-$stamp.zip"
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

function Search([object[]]$Files,[string]$Pattern) {
    return @($Files | Select-String -SimpleMatch -Pattern $Pattern -ErrorAction SilentlyContinue)
}

trap {
    Log ""
    Log "PHASE 008R3A.3 PREFLIGHT: FAILED"
    Log ($_ | Out-String)
    if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force -ErrorAction SilentlyContinue
    Write-Host "ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.3 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Legacy Asset Migration Contract" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$assetRoot = Join-Path $root "packages\assets"
$metadata = Join-Path $assetRoot "src\metadata.ts"
$index = Join-Path $assetRoot "src\index.ts"
$sourceReadme = Join-Path $assetRoot "source\README.md"

foreach ($required in @($metadata,$index,$sourceReadme)) {
    if (-not (Test-Path $required)) { throw "008R3A.2 foundation missing: $required" }
}

$all = @(
    (Get-Files $assetRoot @("*.ts","*.tsx","*.json","*.svg","*.png","*.webp","*.md")) +
    (Get-Files (Join-Path $root "apps") @("*.ts","*.tsx","*.json")) +
    (Get-Files (Join-Path $root "content") @("*.json","*.ts")) +
    (Get-Files (Join-Path $root "tools\content-compiler") @("*.mjs","*.ts","*.json"))
)

$ids = @("apple-red","apple-green","banana-yellow","hibiscus-red","hibiscus-yellow","hibiscus-purple")

Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
Log "Files inspected: $($all.Count)"
Log ""
Log "REFERENCE MATRIX"

$summary = @()
foreach ($id in $ids) {
    $hits = Search $all $id
    $files = @($hits | ForEach-Object {$_.Path} | Sort-Object -Unique)
    Log "$id | hits=$($hits.Count) | files=$($files.Count)"
    foreach ($f in $files) {
        Log ("  " + $f.Substring($root.Length).TrimStart("\"))
    }
    $summary += [PSCustomObject]@{
        id=$id
        hits=$hits.Count
        files=@($files | ForEach-Object {$_.Substring($root.Length).TrimStart("\")})
    }
}

Log ""
Log "PHYSICAL ASSET INVENTORY"
$physical = @(Get-Files $assetRoot @("*.svg","*.png","*.webp","*.avif"))
foreach ($f in ($physical | Sort-Object FullName)) {
    Log ("{0} | {1} bytes" -f $f.FullName.Substring($root.Length).TrimStart("\"),$f.Length)
}

Log ""
Log "DIRECT PHYSICAL-PATH KNOWLEDGE"
foreach ($pattern in @("src/generated",".svg",".png",".webp")) {
    $hits = @(
        $all |
        Where-Object {$_.Extension -in @(".ts",".tsx",".mjs",".json")} |
        Select-String -SimpleMatch -Pattern $pattern -ErrorAction SilentlyContinue
    )
    Log "$pattern | hits=$($hits.Count)"
    foreach ($h in $hits) {
        Log ("  {0}:{1}: {2}" -f $h.Path.Substring($root.Length).TrimStart("\"),$h.LineNumber,$h.Line.Trim())
    }
}

Log ""
Log "MIGRATION SAFETY QUESTIONS"
Log "1. Which legacy physical files are runtime dependencies versus obsolete generated artefacts?"
Log "2. Which files are authoritative masters, derivatives, or prototypes?"
Log "3. Can hibiscus masters be moved under source/ without breaking generated commercial imports?"
Log "4. Can fruit SVGs remain temporarily while fruit raster replacements are not yet available?"
Log "5. Which generated files must remain compiler-owned and must never be hand-edited?"
Log "6. Which exact references must be migrated before any physical deletion?"
Log "7. Does any learner/runtime consumer bypass getAsset() after 008R3A.2?"
Log "8. Migration must preserve semantic IDs and activity manifests."
Log "9. Preflight performs no move, deletion, conversion, approval or manifest edit."

$summary | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $work "reference-matrix.json") -Encoding UTF8

Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
Write-Host ""
Write-Host "PASS: Phase 008R3A.3 migration preflight" -ForegroundColor Green
Write-Host "ZIP: $zip" -ForegroundColor Cyan
Write-Host "No repository file was modified." -ForegroundColor Cyan
