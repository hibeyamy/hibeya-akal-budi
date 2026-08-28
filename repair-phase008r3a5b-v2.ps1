Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3a5b-repair-v2-" + $stamp)
$log = Join-Path $work "phase008r3a5b-repair-v2.log"
$zip = Join-Path $logs ("phase008r3a5b-repair-v2-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Write-Log {
    param([string]$Text = "")
    Add-Content -Path $log -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Run-Native {
    param(
        [string]$Label,
        [string]$Command
    )

    Write-Log ""
    Write-Log ("==> " + $Label)
    Write-Log $Command

    $stdout = Join-Path $work "stdout.txt"
    $stderr = Join-Path $work "stderr.txt"

    $process = Start-Process -FilePath "cmd.exe" -ArgumentList @("/d","/s","/c",$Command) -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr

    foreach ($file in @($stdout,$stderr)) {
        if (Test-Path $file) {
            $text = Get-Content -Path $file -Raw -ErrorAction SilentlyContinue
            if ($text) {
                Write-Log $text.TrimEnd()
            }
            Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        }
    }

    if ($process.ExitCode -ne 0) {
        throw ($Label + " failed with exit code " + $process.ExitCode)
    }

    Write-Log ("PASS: " + $Label)
}

function Save-Zip {
    if (Test-Path $zip) {
        Remove-Item -Path $zip -Force -ErrorAction SilentlyContinue
    }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

trap {
    Write-Log ""
    Write-Log "PHASE 008R3A.5B REPAIR V2: FAILED"
    Write-Log ($_ | Out-String)
    Write-Log $_.ScriptStackTrace
    Save-Zip
    Write-Host ""
    Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.5B REPAIR V2" -ForegroundColor Cyan
Write-Host "Candidate Review Validation Resume" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$reviewDir = Join-Path $root "packages\assets\source\review\fruit"
$inspectorSource = Join-Path $root "phase008r3a5b-inspect-candidates-v2.mjs"
$inspectorTarget = Join-Path $root "tools\assets\inspect-fruit-candidates.mjs"

if (-not (Test-Path $reviewDir)) {
    throw ("Review directory missing: " + $reviewDir)
}

if (-not (Test-Path $inspectorSource)) {
    throw ("Inspector companion missing: " + $inspectorSource)
}

$ids = @("apple-red","apple-green","banana-yellow")

foreach ($id in $ids) {
    $png = Join-Path $reviewDir ($id + ".png")
    $recordPath = Join-Path $reviewDir ($id + ".review.json")

    if (-not (Test-Path $png)) {
        throw ("Missing staged PNG: " + $png)
    }

    if (-not (Test-Path $recordPath)) {
        throw ("Missing review record: " + $recordPath)
    }

    $record = Get-Content -Path $recordPath -Raw | ConvertFrom-Json

    if ($record.visualReviewed -ne $true) {
        throw ("Human visual review was not preserved for " + $id)
    }

    if ($record.productionEnabled -eq $true) {
        throw ("Candidate is already production-enabled: " + $id)
    }

    Write-Log ("PASS: prior human visual review preserved for " + $id)
}

Copy-Item -Path $inspectorSource -Destination $inspectorTarget -Force
Write-Log "PASS: technical candidate inspector installed"
Write-Log "PASS: no re-staging and no review-flag rewrite performed"

Run-Native "Verify project-local Sharp" "node -e ""import('sharp').then(()=>console.log('sharp available')).catch(e=>{console.error(e);process.exit(1)})"""
Run-Native "Inspect staged fruit PNG candidates" "node tools/assets/inspect-fruit-candidates.mjs"

$runtimeText = ""
$runtimeFiles = @(
    "packages\assets\src\generated\commercialRegistry.generated.ts",
    "packages\assets\src\commercial.ts",
    "packages\assets\src\index.ts"
)

foreach ($relative in $runtimeFiles) {
    $full = Join-Path $root $relative
    if (Test-Path $full) {
        $runtimeText = $runtimeText + (Get-Content -Path $full -Raw) + "`n"
    }
}

foreach ($id in $ids) {
    $webpNeedle = "./" + $id + ".webp"
    if ($runtimeText -match [Regex]::Escape($webpNeedle)) {
        throw ("Fruit WebP leaked into runtime before controlled promotion: " + $id)
    }
}

Write-Log "PASS: reviewed fruit candidates remain outside production runtime"

Run-Native "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run-Native "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run-Native "Learner typecheck" "pnpm --filter learner-web typecheck"
Run-Native "Learner tests" "pnpm --filter learner-web test"
Run-Native "Raster pipeline reproducibility" "node tools/assets/build-raster-assets.mjs --check"
Run-Native "Frozen lockfile" "pnpm install --frozen-lockfile"
Run-Native "Git whitespace" "git diff --check"

Write-Log ""
Write-Log "PHASE 008R3A.5B REPAIR V2: PASS"
Write-Log "Human visual approvals remain recorded."
Write-Log "All staged fruit PNG candidates pass technical inspection."
Write-Log "No fruit asset has been promoted to production."
Write-Log "Next: Phase 008R3A.5C controlled promotion."

Save-Zip

Write-Host ""
Write-Host "PHASE 008R3A.5B REPAIR V2: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
