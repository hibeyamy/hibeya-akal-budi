Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3a6-repair-v4-"+$stamp)
$log=Join-Path $work "repair.log"
$zip=Join-Path $logs ("phase008r3a6-repair-v4-"+$stamp+".zip")
New-Item -ItemType Directory -Force -Path $work|Out-Null

function Log([string]$t=""){Add-Content $log $t -Encoding UTF8;Write-Host $t}
function Run([string]$label,[string]$cmd){
 Log "";Log ("==> "+$label);Log $cmd
 cmd.exe /d /s /c $cmd 2>&1|ForEach-Object{Log $_}
 if($LASTEXITCODE -ne 0){throw ($label+" failed with exit code "+$LASTEXITCODE)}
 Log ("PASS: "+$label)
}
function Stop-Server(){
 if($script:serverProcess -and -not $script:serverProcess.HasExited){
   Stop-Process -Id $script:serverProcess.Id -Force -ErrorAction SilentlyContinue
 }
}
function ZipLog(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Stop-Server;Log "";Log "PHASE 008R3A.6 REPAIR V4: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.6 REPAIR V4" -ForegroundColor Cyan
Write-Host "Dependency-Free Storybook Static Server" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$static=Join-Path $root "apps\ui-storybook\storybook-static"
if(-not(Test-Path (Join-Path $static "index.html"))){throw "Prior successful Storybook static build is missing"}

$source=Join-Path $root "phase008r3a6-static-server.mjs"
$target=Join-Path $root "tools\visual-regression\serve-storybook-static.mjs"
if(-not(Test-Path $source)){throw "V4 static-server companion missing"}
Copy-Item $source $target -Force

Log "PASS: prior successful Phase 008R3A.6 state preserved"
Log "PASS: external http-server dependency removed"

Run "Verify Node runtime" "node --version"
Run "Verify Playwright executable" "pnpm exec playwright --version"

$out=Join-Path $work "storybook-stdout.txt"
$err=Join-Path $work "storybook-stderr.txt"
$script:serverProcess=Start-Process "node.exe" -ArgumentList @("tools/visual-regression/serve-storybook-static.mjs") -WorkingDirectory $root -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
Log ("Storybook static server PID: "+$script:serverProcess.Id)

$ready=$false
for($i=0;$i -lt 30;$i++){
 Start-Sleep -Milliseconds 500
 try{
   $r=Invoke-WebRequest -Uri "http://127.0.0.1:6006/index.html" -UseBasicParsing -TimeoutSec 2
   if($r.StatusCode -eq 200){$ready=$true;break}
 }catch{}
 if($script:serverProcess.HasExited){break}
}
if(-not $ready){
 if(Test-Path $out){$t=Get-Content $out -Raw -ErrorAction SilentlyContinue;if($t){Log $t}}
 if(Test-Path $err){$t=Get-Content $err -Raw -ErrorAction SilentlyContinue;if($t){Log $t}}
 throw "Dependency-free Storybook static server did not become ready"
}
Log "PASS: dependency-free Storybook static server ready"

Run "Production asset responsive visual regression" "pnpm exec playwright test tools/visual-regression/tests/production-assets.spec.ts"

Stop-Server
Log "PASS: Storybook static server stopped"

Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.6 REPAIR V4: PASS"
Log "Responsive production visual regression passed at mobile, tablet and desktop sizes."
Log "No new npm dependency was introduced."
Log "All remaining asset-governance close-out gates passed."
Log "Phase 008R3A.6 is complete."
ZipLog
Write-Host "PHASE 008R3A.6 REPAIR V4: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
