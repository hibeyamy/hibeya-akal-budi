Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3b3-repair-v1-"+$stamp)
$log=Join-Path $work "repair.log"
$zip=Join-Path $logs ("phase008r3b3-repair-v1-"+$stamp+".zip")
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
function ZipLog(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Log "";Log "PHASE 008R3B.3 REPAIR V1: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.3 REPAIR V1" -ForegroundColor Cyan
Write-Host "Exact Post-R3B.2 ActivityPlayer Boundary" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$player=Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
if(-not(Test-Path $player)){throw "ActivityPlayer.tsx missing"}
Copy-Item $player (Join-Path $work "ActivityPlayer-before.tsx") -Force

Run "Apply corrected state-observability patch" "node repair-phase008r3b3-v1-patch.mjs"

$after=Get-Content $player -Raw
foreach($needle in @('data-testid="activity-player"','data-activity-state=','data-answer-count=','data-session-mode=','data-feedback-state=')){
 if(-not $after.Contains($needle)){throw ("State hook missing: "+$needle)}
}
Log "PASS: state observability installed"

foreach($needle in @("mechanic.submitAnswer(","addLocalAnswer(","completeLocalSession(","recordSessionSkillMastery(","recordCompletedJourneyActivity(")){
 if(-not $after.Contains($needle)){throw ("Learning contract missing: "+$needle)}
}
Log "PASS: learning/session/mastery contracts retained"

$src=Join-Path $root "phase008r3b3-production-state.spec.ts"
$dst=Join-Path $root "tools\visual-regression\tests\learner-production-state.spec.ts"
if(-not(Test-Path $src)){throw "Original R3B.3 production-state spec is missing. Keep the files from the original package in repository root."}
Copy-Item $src $dst -Force
Log "PASS: production state regression spec installed"

Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Learner lint" "pnpm --filter learner-web lint"
Run "Learner production build" "pnpm --filter learner-web build"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"

Log ""
Log "PHASE 008R3B.3 REPAIR V1: PASS"
Log "Corrected patch matched the actual post-R3B.2 ActivityPlayer main boundary."
Log "Production state observability and R3B.4 regression specification are installed."
Log "No fabricated loading/error state was introduced."
ZipLog
Write-Host "PHASE 008R3B.3 REPAIR V1: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
