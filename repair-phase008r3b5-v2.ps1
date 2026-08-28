Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3b5-repair-v2-" + $stamp)
$log = Join-Path $work "repair.log"
$zip = Join-Path $logs ("phase008r3b5-repair-v2-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Write-Log([string]$Text = "") {
    Add-Content -Path $log -Value $Text -Encoding UTF8
    Write-Host $Text
}

function Invoke-Step([string]$Label, [string]$Command) {
    Write-Log ""
    Write-Log ("==> " + $Label)
    Write-Log $Command

    $stdout = Join-Path $work "stdout.txt"
    $stderr = Join-Path $work "stderr.txt"

    $process = Start-Process "cmd.exe" `
        -ArgumentList @("/d", "/s", "/c", $Command) `
        -WorkingDirectory $root `
        -Wait `
        -NoNewWindow `
        -PassThru `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr

    foreach ($file in @($stdout, $stderr)) {
        if (Test-Path $file) {
            $content = Get-Content -Path $file -Raw -ErrorAction SilentlyContinue
            if ($content) { Write-Log $content.TrimEnd() }
            Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        }
    }

    if ($process.ExitCode -ne 0) {
        throw ($Label + " failed with exit code " + $process.ExitCode)
    }

    Write-Log ("PASS: " + $Label)
}

function Save-DiagnosticZip {
    foreach ($candidate in @("test-results", "playwright-report")) {
        $source = Join-Path $root $candidate
        if (Test-Path $source) {
            Copy-Item $source (Join-Path $work $candidate) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

trap {
    Write-Log ""
    Write-Log "PHASE 008R3B.5 REPAIR V2: FAILED"
    Write-Log ($_ | Out-String)
    Write-Log $_.ScriptStackTrace
    Save-DiagnosticZip
    Write-Host ("ZIP: " + $zip) -ForegroundColor Yellow
    exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.5 REPAIR V2" -ForegroundColor Cyan
Write-Host "PowerShell Runner + Accessibility Repair" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Invoke-Step "Repair nested main landmark" "node repair-phase008r3b5-v2-patch.mjs"

$sourceSpec = Join-Path $root "repair-phase008r3b5-v2-accessibility.spec.ts"
$targetSpec = Join-Path $root "tools\visual-regression\tests\learner-accessibility.spec.ts"
Copy-Item $sourceSpec $targetSpec -Force
Write-Log "PASS: corrected accessibility regression installed"

Invoke-Step "Learner typecheck" "pnpm --filter learner-web typecheck"
Invoke-Step "Storybook production build" "pnpm storybook:build"
Invoke-Step "Accessibility interaction regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-accessibility.spec.ts"
Invoke-Step "Responsive regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-responsive-production.spec.ts"
Invoke-Step "Journey regression" "pnpm qa:journey"
Invoke-Step "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Invoke-Step "Content reproducibility" "node tools/content-compiler/compile.mjs --check"
Invoke-Step "Asset registry reproducibility" "node tools/assets/compile-commercial-registry.mjs --check"
Invoke-Step "Frozen lockfile" "pnpm install --frozen-lockfile"

Write-Log ""
Write-Log "PHASE 008R3B.5 REPAIR V2: PASS"
Write-Log "Nested main landmark repaired."
Write-Log "Keyboard focus uses genuine Tab traversal."
Write-Log "Reduced-motion assertion accepts effectively-zero browser serialisation."
Write-Log "Responsive and learner journey regressions remain green."

Save-DiagnosticZip
Write-Host "PHASE 008R3B.5 REPAIR V2: PASS" -ForegroundColor Green
Write-Host ("ZIP: " + $zip) -ForegroundColor Cyan
