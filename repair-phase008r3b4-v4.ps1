Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3b4-repair-v4-"+$stamp)
$log=Join-Path $work "repair.log"
$zip=Join-Path $logs ("phase008r3b4-repair-v4-"+$stamp+".zip")
New-Item -ItemType Directory -Force -Path $work|Out-Null
function Log([string]$t=""){Add-Content $log $t -Encoding UTF8;Write-Host $t}
function Run([string]$label,[string]$cmd){
 Log "";Log ("==> "+$label);Log $cmd
 $o=Join-Path $work "out.txt";$e=Join-Path $work "err.txt"
 $p=Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$cmd) -WorkingDirectory $root -Wait -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
 foreach($f in @($o,$e)){if(Test-Path $f){$x=Get-Content $f -Raw -ErrorAction SilentlyContinue;if($x){Log $x.TrimEnd()};Remove-Item $f -Force -ErrorAction SilentlyContinue}}
 if($p.ExitCode -ne 0){throw ($label+" failed with exit code "+$p.ExitCode)}
 Log ("PASS: "+$label)
}
function ZipLog(){
 foreach($candidate in @("test-results","playwright-report")){
   $src=Join-Path $root $candidate
   if(Test-Path $src){Copy-Item $src (Join-Path $work $candidate) -Recurse -Force -ErrorAction SilentlyContinue}
 }
 if(Test-Path $zip){Remove-Item $zip -Force}
 Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}
trap{Log "";Log "PHASE 008R3B.4 REPAIR V4: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.4 REPAIR V4" -ForegroundColor Cyan
Write-Host "Storybook CSS Boundary Typecheck Repair" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Run "Move learner stylesheet to Storybook preview boundary" "node repair-phase008r3b4-v4-patch.mjs"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Storybook production build" "pnpm storybook:build"
Run "Responsive production activity regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-responsive-production.spec.ts"
Run "Existing learner journey regression" "pnpm qa:journey"
Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Asset registry reproducibility" "node tools/assets/compile-commercial-registry.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"

Log ""
Log "PHASE 008R3B.4 REPAIR V4: PASS"
Log "Learner stylesheet is now loaded at the Storybook preview boundary rather than from a typed story module."
Log "Storybook typecheck and production build passed."
Log "Responsive production QA passed at mobile, tablet and desktop."
Log "Existing learner journey regression remains green."
Log "No learner production logic, curriculum, asset or dependency was changed."
ZipLog
Write-Host "PHASE 008R3B.4 REPAIR V4: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
