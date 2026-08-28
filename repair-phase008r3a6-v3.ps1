Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3a6-repair-v3-"+$stamp)
$log=Join-Path $work "repair.log"
$zip=Join-Path $logs ("phase008r3a6-repair-v3-"+$stamp+".zip")
New-Item -ItemType Directory -Force -Path $work|Out-Null

function Log([string]$t=""){Add-Content $log $t -Encoding UTF8;Write-Host $t}
function Run([string]$label,[string]$cmd){
 Log "";Log ("==> "+$label);Log $cmd
 cmd.exe /d /s /c $cmd 2>&1|ForEach-Object{Log $_}
 if($LASTEXITCODE -ne 0){throw ($label+" failed with exit code "+$LASTEXITCODE)}
 Log ("PASS: "+$label)
}
function ZipLog(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
function Stop-Storybook(){
 if($script:storybookProcess -and -not $script:storybookProcess.HasExited){
   Stop-Process -Id $script:storybookProcess.Id -Force -ErrorAction SilentlyContinue
 }
}
trap{Stop-Storybook;Log "";Log "PHASE 008R3A.6 REPAIR V3: FAILED";Log ($_|Out-String);ZipLog;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.6 REPAIR V3" -ForegroundColor Cyan
Write-Host "Storybook Server + Absolute Playwright URL" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$source=Join-Path $root "phase008r3a6-production-assets-v3.spec.ts"
$target=Join-Path $root "tools\visual-regression\tests\production-assets.spec.ts"
if(-not(Test-Path $source)){throw "V3 Playwright test companion missing"}
Copy-Item $source $target -Force
Log "PASS: visual test now uses explicit Storybook URL"

Run "Verify Playwright executable" "pnpm exec playwright --version"

# Serve the already-built Storybook rather than rebuilding it.
$storybookStatic=Join-Path $root "apps\ui-storybook\storybook-static"
if(-not(Test-Path $storybookStatic)){throw "Storybook static build missing; prior build was expected to have passed"}

$serveOut=Join-Path $work "storybook-stdout.txt"
$serveErr=Join-Path $work "storybook-stderr.txt"
$script:storybookProcess=Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c","pnpm exec http-server apps/ui-storybook/storybook-static -a 127.0.0.1 -p 6006 -c-1") -WorkingDirectory $root -NoNewWindow -PassThru -RedirectStandardOutput $serveOut -RedirectStandardError $serveErr
Log ("Storybook static server PID: "+$script:storybookProcess.Id)

$ready=$false
for($i=0;$i -lt 30;$i++){
 Start-Sleep -Milliseconds 500
 try{
   $r=Invoke-WebRequest -Uri "http://127.0.0.1:6006/index.html" -UseBasicParsing -TimeoutSec 2
   if($r.StatusCode -eq 200){$ready=$true;break}
 }catch{}
 if($script:storybookProcess.HasExited){break}
}
if(-not $ready){
 if(Test-Path $serveOut){Log (Get-Content $serveOut -Raw)}
 if(Test-Path $serveErr){Log (Get-Content $serveErr -Raw)}
 throw "Storybook static server did not become ready on 127.0.0.1:6006"
}
Log "PASS: Storybook static server ready"

Run "Production asset responsive visual regression" "pnpm exec playwright test tools/visual-regression/tests/production-assets.spec.ts"

Stop-Storybook
Log "PASS: Storybook static server stopped"

Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.6 REPAIR V3: PASS"
Log "Mobile, tablet and desktop production asset regression passed against served Storybook."
Log "All remaining close-out gates passed."
Log "Phase 008R3A.6 is complete."
ZipLog
Write-Host "PHASE 008R3A.6 REPAIR V3: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
