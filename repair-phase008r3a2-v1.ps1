Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs "phase008r3a2-repair-v1-$stamp"
$log = Join-Path $work "phase008r3a2-repair-v1.log"
$zip = Join-Path $logs "phase008r3a2-repair-v1-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
    [IO.File]::AppendAllText(
        $log,
        $Text + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
    Write-Host $Text
}

function Run-Native([string]$Label, [string]$Command) {
    Log ""
    Log "==> $Label"
    Log $Command

    $stdout = Join-Path $work ("stdout-" + [Guid]::NewGuid().ToString("N") + ".txt")
    $stderr = Join-Path $work ("stderr-" + [Guid]::NewGuid().ToString("N") + ".txt")

    $process = Start-Process `
        -FilePath "cmd.exe" `
        -ArgumentList @("/d", "/s", "/c", $Command) `
        -WorkingDirectory $root `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr

    foreach ($path in @($stdout, $stderr)) {
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

trap {
    Log ""
    Log "PHASE 008R3A.2 REPAIR V1: FAILED"
    Log ($_ | Out-String)
    Log $_.ScriptStackTrace

    if (Test-Path $zip) {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Yellow
    exit 1
}

Set-Location $root

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.2 REPAIR V1" -ForegroundColor Cyan
Write-Host "PowerShell-safe Native Validation Resume" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"

$metadata = Join-Path $root "packages\assets\src\metadata.ts"
$index = Join-Path $root "packages\assets\src\index.ts"
$baseline = Join-Path $root "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx"
$hibiscus = Join-Path $root "apps\ui-storybook\stories\HibiscusAssets.stories.tsx"
$sourceReadme = Join-Path $root "packages\assets\source\README.md"

foreach ($required in @($metadata,$index,$baseline,$hibiscus,$sourceReadme)) {
    if (-not (Test-Path $required)) {
        throw "Partial Phase 008R3A.2 state missing expected file: $required"
    }
}

$indexText = Get-Content $index -Raw
$baselineText = Get-Content $baseline -Raw
$hibiscusText = Get-Content $hibiscus -Raw

if ($indexText -notmatch 'getAssetMetadata') {
    throw "Asset metadata export is missing from the partial Phase 008R3A.2 state."
}

foreach ($story in @($baselineText,$hibiscusText)) {
    if ($story -notmatch 'getAsset') {
        throw "A review story is not using getAsset()."
    }
    if ($story -match 'src/generated' -or
        $story -match '\.svg' -or
        $story -match '\.png' -or
        $story -match '\.webp') {
        throw "A review story still contains physical asset path/format knowledge."
    }
}

Log "PASS: partial Phase 008R3A.2 implementation state verified"
Log "PASS: no source rewrite required before validation resume"
Log "PASS: native runner now captures stdout/stderr independently and judges only process exit code"

Run-Native "Verify frozen lockfile" "pnpm install --frozen-lockfile"
Run-Native "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run-Native "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run-Native "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run-Native "Learner web tests" "pnpm --filter learner-web test"
Run-Native "Storybook production build" "pnpm --filter ui-storybook build-storybook"

if (Test-Path (Join-Path $root "tools\content-compiler\compile.mjs")) {
    Run-Native "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
}

Log ""
Log "PASS: Phase 008R3A.2 Asset Architecture Foundation"
Log "PASS: repair confirms original failure was native stderr handling, not assumed TypeScript failure"
Log "Next: Phase 008R3A.3 Legacy Asset Migration"
Log "No activity manifest, approval state, progression rule, or curriculum ordering rule was changed by this repair."

if (Test-Path $zip) {
    Remove-Item $zip -Force
}
Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force

Write-Host ""
Write-Host "PHASE 008R3A.2 REPAIR V1: PASS" -ForegroundColor Green
Write-Host "Log ZIP: $zip" -ForegroundColor Cyan
exit 0
