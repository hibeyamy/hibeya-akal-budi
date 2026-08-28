Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs "phase008r3a4-raster-pipeline-$stamp"
$log=Join-Path $work "phase008r3a4.log"
$zip=Join-Path $logs "phase008r3a4-raster-pipeline-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$t=""){Add-Content -Path $log -Value $t -Encoding UTF8; Write-Host $t}
function Run([string]$label,[string]$command){
  Log ""; Log "==> $label"; Log $command
  $o=Join-Path $work "stdout.txt"; $e=Join-Path $work "stderr.txt"
  $p=Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$command) -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
  foreach($f in @($o,$e)){if(Test-Path $f){$t=Get-Content $f -Raw -ErrorAction SilentlyContinue;if($t){Log $t.TrimEnd()};Remove-Item $f -Force}}
  if($p.ExitCode -ne 0){throw "$label failed with exit code $($p.ExitCode)"}
  Log "PASS: $label"
}
function ZipLog(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap {Log "PHASE 008R3A.4: FAILED";Log ($_|Out-String);ZipLog;Write-Host "ZIP: $zip" -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.4" -ForegroundColor Cyan
Write-Host "Governed Raster Asset Pipeline" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$pipelineSource=Join-Path $root "phase008r3a4-build-raster-assets.mjs"
$pipelineTarget=Join-Path $root "tools\assets\build-raster-assets.mjs"
if(-not(Test-Path $pipelineSource)){throw "Companion pipeline file missing: $pipelineSource"}
if(-not(Test-Path "packages\assets\source\masters\flora")){throw "008R3A.3 master directory missing"}
if(-not(Test-Path "tools\assets\compile-commercial-registry.mjs")){throw "Commercial registry compiler missing"}

Run "Verify project-local Sharp" "node -e ""import('sharp').then(()=>console.log('sharp available')).catch(e=>{console.error(e);process.exit(1)})"""

Copy-Item $pipelineSource $pipelineTarget -Force
Log "PASS: canonical raster pipeline installed"

Run "Generate governed WebP derivatives" "node tools/assets/build-raster-assets.mjs"
Run "Verify deterministic derivatives" "node tools/assets/build-raster-assets.mjs --check"
Run "Compile commercial registry" "node tools/assets/compile-commercial-registry.mjs"
Run "Verify derivatives after registry generation" "node tools/assets/build-raster-assets.mjs --check"

$registry=Get-Content "packages\assets\src\generated\commercialRegistry.generated.ts" -Raw
foreach($id in @("hibiscus-red","hibiscus-yellow","hibiscus-purple")){
 if($registry -notmatch [regex]::Escape("./$id.webp")){throw "Registry missing WebP: $id"}
 if($registry -match [regex]::Escape("./$id.png") -or $registry -match [regex]::Escape("./$id.svg")){throw "Registry leaked source/legacy format: $id"}
}
Log "PASS: registry exposes hibiscus WebP delivery only"

Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Storybook build" "pnpm --filter ui-storybook build-storybook"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log "PHASE 008R3A.4: PASS"
Log "PNG master -> project-local Sharp -> deterministic WebP -> generated registry -> getAsset()."
Log "Fruit migration remains deferred."
Log "Next: Phase 008R3A.5 Visual Asset Replacement."
ZipLog
Write-Host "PHASE 008R3A.4: PASS" -ForegroundColor Green
Write-Host "ZIP: $zip" -ForegroundColor Cyan
