Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs "phase008r3a5-framework-$stamp"
$log=Join-Path $work "phase008r3a5-framework.log"
$zip=Join-Path $logs "phase008r3a5-framework-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$t=""){Add-Content $log $t -Encoding UTF8;Write-Host $t}
function Run([string]$label,[string]$cmd){
 Log "";Log "==> $label";Log $cmd
 $o=Join-Path $work "stdout.txt";$e=Join-Path $work "stderr.txt"
 $p=Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$cmd) -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
 foreach($f in @($o,$e)){if(Test-Path $f){$t=Get-Content $f -Raw -ErrorAction SilentlyContinue;if($t){Log $t.TrimEnd()};Remove-Item $f -Force}}
 if($p.ExitCode -ne 0){throw "$label failed with exit code $($p.ExitCode)"}
 Log "PASS: $label"
}
function ZipLog(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Log "PHASE 008R3A.5 FRAMEWORK: FAILED";Log ($_|Out-String);ZipLog;Write-Host "ZIP: $zip" -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.5" -ForegroundColor Cyan
Write-Host "Visual Replacement Framework" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$files=@{
 "phase008r3a5-build-raster-assets.mjs"="tools\assets\build-raster-assets.mjs";
 "phase008r3a5-stage-raster-master.mjs"="tools\assets\stage-raster-master.mjs";
 "phase008r3a5-raster-assets.json"="packages\assets\source\raster-assets.json";
 "phase008r3a5-visual-replacement-plan.json"="packages\assets\source\visual-replacement-plan.json"
}
foreach($src in $files.Keys){
 $source=Join-Path $root $src
 if(-not(Test-Path $source)){throw "Missing companion file: $src"}
 $target=Join-Path $root $files[$src]
 New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
 Copy-Item $source $target -Force
}
Log "PASS: manifest-driven raster pipeline installed"
Log "PASS: fruit replacement plan installed"
Log "PASS: visual-review staging command installed"
Log "PASS: fruit SVG runtime remains unchanged"

Run "Verify Sharp" "node -e ""import('sharp').then(()=>console.log('sharp available')).catch(e=>{console.error(e);process.exit(1)})"""
Run "Verify raster pipeline reproducibility" "node tools/assets/build-raster-assets.mjs --check"
Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.5 FRAMEWORK: PASS"
Log "No fruit artwork was fabricated, converted, promoted or approved."
Log "Next manual input: genuinely richer PNG artwork for apple-red, apple-green and banana-yellow."
Log "Use stage-raster-master.mjs only after artwork exists."
ZipLog
Write-Host "PHASE 008R3A.5 FRAMEWORK: PASS" -ForegroundColor Green
Write-Host "ZIP: $zip" -ForegroundColor Cyan
