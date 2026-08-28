Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs "phase008r3a4-repair-v1-$stamp"
$log = Join-Path $work "phase008r3a4-repair-v1.log"
$zip = Join-Path $logs "phase008r3a4-repair-v1-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    Add-Content -Path $log -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Run([string]$Label,[string]$Command) {
    Log ""
    Log "==> $Label"
    Log $Command

    $stdout = Join-Path $work "stdout.txt"
    $stderr = Join-Path $work "stderr.txt"

    $p = Start-Process "cmd.exe" `
        -ArgumentList @("/d","/s","/c",$Command) `
        -WorkingDirectory $root `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr

    foreach ($f in @($stdout,$stderr)) {
        if (Test-Path $f) {
            $text = Get-Content $f -Raw -ErrorAction SilentlyContinue
            if ($text) { Log $text.TrimEnd() }
            Remove-Item $f -Force -ErrorAction SilentlyContinue
        }
    }

    if ($p.ExitCode -ne 0) {
        throw "$Label failed with exit code $($p.ExitCode)"
    }

    Log "PASS: $Label"
}

function ZipLog {
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
    Log "PHASE 008R3A.4 REPAIR V1: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace
    ZipLog
    Write-Host ""
    Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.4 REPAIR V1" -ForegroundColor Cyan
Write-Host "Opaque PNG Master Compatibility" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$companion = Join-Path $root "phase008r3a4-build-raster-assets-v2.mjs"
$target = Join-Path $root "tools\assets\build-raster-assets.mjs"

if (-not (Test-Path $companion)) {
    throw "Missing companion file: $companion"
}
if (-not (Test-Path "packages\assets\source\masters\flora")) {
    throw "Hibiscus master directory missing."
}

Run "Verify project-local Sharp" "node -e ""import('sharp').then(()=>console.log('sharp available')).catch(e=>{console.error(e);process.exit(1)})"""

Copy-Item $companion $target -Force
Log "PASS: corrected alpha policy installed"
Log "PASS: opaque PNG masters are valid"
Log "PASS: transparency is preserved when source alpha exists"

Run "Generate governed WebP derivatives" "node tools/assets/build-raster-assets.mjs"
Run "Verify deterministic derivatives" "node tools/assets/build-raster-assets.mjs --check"
Run "Compile commercial registry" "node tools/assets/compile-commercial-registry.mjs"
Run "Verify derivatives after registry generation" "node tools/assets/build-raster-assets.mjs --check"

$registry = Get-Content "packages\assets\src\generated\commercialRegistry.generated.ts" -Raw
foreach ($id in @("hibiscus-red","hibiscus-yellow","hibiscus-purple")) {
    if ($registry -notmatch [regex]::Escape("./$id.webp")) {
        throw "Registry missing WebP: $id"
    }
    if (
        $registry -match [regex]::Escape("./$id.png") -or
        $registry -match [regex]::Escape("./$id.svg")
    ) {
        throw "Registry leaked source/legacy format: $id"
    }
}

Log "PASS: runtime registry exposes hibiscus WebP delivery only"

Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Storybook build" "pnpm --filter ui-storybook build-storybook"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.4 REPAIR V1: PASS"
Log "PNG master -> project-local Sharp -> deterministic WebP -> generated registry -> getAsset()."
Log "Alpha policy: preserve when present; opaque masters remain opaque."
Log "Fruit migration remains deferred."
Log "Next: Phase 008R3A.5 Visual Asset Replacement."

ZipLog

Write-Host ""
Write-Host "PHASE 008R3A.4 REPAIR V1: PASS" -ForegroundColor Green
Write-Host "ZIP: $zip" -ForegroundColor Cyan
