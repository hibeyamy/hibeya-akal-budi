Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3a6-repair-v1-"+$stamp)
$log=Join-Path $work "phase008r3a6-repair-v1.log"
$zip=Join-Path $logs ("phase008r3a6-repair-v1-"+$stamp+".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$t=""){Add-Content $log $t -Encoding UTF8;Write-Host $t}
function Run([string]$label,[string]$cmd){
 Log "";Log ("==> "+$label);Log $cmd
 $o=Join-Path $work "stdout.txt";$e=Join-Path $work "stderr.txt"
 $p=Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$cmd) -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
 foreach($f in @($o,$e)){if(Test-Path $f){$t=Get-Content $f -Raw -ErrorAction SilentlyContinue;if($t){Log $t.TrimEnd()};Remove-Item $f -Force -ErrorAction SilentlyContinue}}
 if($p.ExitCode -ne 0){throw ($label+" failed with exit code "+$p.ExitCode)}
 Log ("PASS: "+$label)
}
function ZipLog(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Log "";Log "PHASE 008R3A.6 REPAIR V1: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host ("Diagnostic ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.6 REPAIR V1" -ForegroundColor Cyan
Write-Host "Validation Resume After Missing Parent Typecheck Script" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Exact partial-state checks: do not repeat successful mutations.
foreach($f in @(
 "packages\assets\src\metadata.ts",
 "packages\assets\source\asset-migration.json",
 "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx",
 "tools\visual-regression\tests\production-assets.spec.ts"
)){if(-not(Test-Path (Join-Path $root $f))){throw ("Expected Phase 008R3A.6 partial state missing: "+$f)}}
Log "PASS: Phase 008R3A.6 partial implementation state exists"

Run "Raster reproducibility" "node tools/assets/build-raster-assets.mjs --check"
Run "Commercial registry reproducibility" "node tools/assets/compile-commercial-registry.mjs --check"
Run "Controlled fruit promotion verification" "node tools/assets/verify-fruit-promotion.mjs"
Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"

# parent-web has no typecheck package script. Validate its TS config directly when present.
$parentTs=Join-Path $root "apps\parent-web\tsconfig.json"
if(Test-Path $parentTs){
 Run "Parent web TypeScript validation" "pnpm exec tsc --noEmit -p apps/parent-web/tsconfig.json"
}else{
 Log "SKIP: parent-web has no tsconfig.json; package also has no typecheck script"
}

Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Storybook production build" "pnpm --filter ui-storybook build-storybook"
Run "Production asset responsive visual regression" "pnpm --dir tools/visual-regression exec playwright test tests/production-assets.spec.ts"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.6 REPAIR V1: PASS"
Log "Existing successful governance mutations were preserved."
Log "Parent-web validation no longer assumes a missing package script."
Log "Responsive production asset regression and remaining close-out gates passed."
Log "Phase 008R3A.6 is complete."
ZipLog
Write-Host "PHASE 008R3A.6 REPAIR V1: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: "+$zip) -ForegroundColor Cyan
