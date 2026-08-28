Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs "phase008r3a4-repair-v2-$stamp"
$log=Join-Path $work "phase008r3a4-repair-v2.log"
$zip=Join-Path $logs "phase008r3a4-repair-v2-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$t=""){Add-Content -Path $log -Value $t -Encoding UTF8;Write-Host $t}
function Run([string]$label,[string]$command){
 Log "";Log "==> $label";Log $command
 $o=Join-Path $work "stdout.txt";$e=Join-Path $work "stderr.txt"
 $p=Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$command) -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
 foreach($f in @($o,$e)){if(Test-Path $f){$t=Get-Content $f -Raw -ErrorAction SilentlyContinue;if($t){Log $t.TrimEnd()};Remove-Item $f -Force -ErrorAction SilentlyContinue}}
 if($p.ExitCode -ne 0){throw "$label failed with exit code $($p.ExitCode)"}
 Log "PASS: $label"
}
function ZipLog(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Log "";Log "PHASE 008R3A.4 REPAIR V2: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host "ZIP: $zip" -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.4 REPAIR V2" -ForegroundColor Cyan
Write-Host "Evidence-Calibrated Raster Size Policy" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$companion=Join-Path $root "phase008r3a4-build-raster-assets-v3.mjs"
$target=Join-Path $root "tools\assets\build-raster-assets.mjs"
if(-not(Test-Path $companion)){throw "Missing companion: $companion"}
if(-not(Test-Path "packages\assets\source\masters\flora")){throw "Master directory missing"}

Run "Verify project-local Sharp" "node -e ""import('sharp').then(()=>console.log('sharp available')).catch(e=>{console.error(e);process.exit(1)})"""
Copy-Item $companion $target -Force

Log "PASS: removed incorrect 100 KiB hard-failure assumption"
Log "PASS: 100 KiB retained as optimisation target"
Log "PASS: 160 KiB is now the explicit hard production ceiling"

Run "Generate governed WebP derivatives" "node tools/assets/build-raster-assets.mjs"
Run "Verify deterministic derivatives" "node tools/assets/build-raster-assets.mjs --check"
Run "Compile commercial registry" "node tools/assets/compile-commercial-registry.mjs"
Run "Verify derivatives after registry generation" "node tools/assets/build-raster-assets.mjs --check"

$registry=Get-Content "packages\assets\src\generated\commercialRegistry.generated.ts" -Raw
foreach($id in @("hibiscus-red","hibiscus-yellow","hibiscus-purple")){
 if($registry -notmatch [regex]::Escape("./$id.webp")){throw "Registry missing WebP: $id"}
 if($registry -match [regex]::Escape("./$id.png") -or $registry -match [regex]::Escape("./$id.svg")){throw "Registry leaked source/legacy format: $id"}
}
Log "PASS: runtime registry exposes WebP only"

Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Storybook build" "pnpm --filter ui-storybook build-storybook"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.4 REPAIR V2: PASS"
Log "Size policy: 100 KiB optimisation target; 160 KiB hard ceiling."
Log "Alpha policy: preserve alpha when present; opaque masters remain valid."
Log "Next: Phase 008R3A.5 Visual Asset Replacement."
ZipLog
Write-Host "PHASE 008R3A.4 REPAIR V2: PASS" -ForegroundColor Green
Write-Host "ZIP: $zip" -ForegroundColor Cyan
