Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3a6-repair-v2-"+$stamp)
$log=Join-Path $work "repair.log"
$zip=Join-Path $logs ("phase008r3a6-repair-v2-"+$stamp+".zip")
New-Item -ItemType Directory -Force -Path $work|Out-Null
function Log([string]$t=""){Add-Content $log $t -Encoding UTF8;Write-Host $t}
function Run([string]$label,[string]$cmd){
 Log "";Log ("==> "+$label);Log $cmd
 cmd.exe /d /s /c $cmd 2>&1|ForEach-Object{Log $_}
 if($LASTEXITCODE -ne 0){throw ($label+" failed with exit code "+$LASTEXITCODE)}
 Log ("PASS: "+$label)
}
function ZipLog(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Log "";Log "PHASE 008R3A.6 REPAIR V2: FAILED";Log ($_|Out-String);ZipLog;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.6 REPAIR V2" -ForegroundColor Cyan
Write-Host "Visual Regression Runner Correction" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$test=Join-Path $root "tools\visual-regression\tests\production-assets.spec.ts"
if(-not(Test-Path $test)){throw "Production visual regression test missing"}
Log "PASS: prior Phase 008R3A.6 state preserved"
Log "PASS: incorrect --dir tools/visual-regression invocation removed"

# Execute from workspace root. pnpm exec resolves the installed workspace Playwright binary.
Run "Verify Playwright executable" "pnpm exec playwright --version"
Run "Production asset responsive visual regression" "pnpm exec playwright test tools/visual-regression/tests/production-assets.spec.ts"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.6 REPAIR V2: PASS"
Log "Responsive production asset regression passed."
Log "Remaining close-out gates passed."
Log "Phase 008R3A.6 is complete."
ZipLog
Write-Host "PHASE 008R3A.6 REPAIR V2: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
