Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3b3-"+$stamp)
$log=Join-Path $work "phase008r3b3.log"
$zip=Join-Path $logs ("phase008r3b3-activity-state-regression-"+$stamp+".zip")
$backup=Join-Path $work "before"
New-Item -ItemType Directory -Force -Path $work,$backup|Out-Null

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
trap{Log "";Log "PHASE 008R3B.3: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.3" -ForegroundColor Cyan
Write-Host "Production Activity State Regression Foundation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$player=Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
if(-not(Test-Path $player)){throw "ActivityPlayer.tsx missing"}
Copy-Item $player (Join-Path $backup "ActivityPlayer.tsx") -Force
Log "PASS: ActivityPlayer before-state captured"

Run "Apply production state-observability patch" "node phase008r3b3-patch.mjs"

$after=Get-Content $player -Raw
foreach($needle in @(
 'data-testid="activity-player"',
 'data-activity-state=',
 'data-answer-count=',
 'data-session-mode=',
 'data-feedback-state='
)){
 if(-not $after.Contains($needle)){throw ("Expected state hook missing: "+$needle)}
}
Log "PASS: production state observability installed"

foreach($needle in @(
 "mechanic.submitAnswer(",
 "addLocalAnswer(",
 "completeLocalSession(",
 "recordSessionSkillMastery(",
 "recordCompletedJourneyActivity("
)){
 if(-not $after.Contains($needle)){throw ("Learning contract missing: "+$needle)}
}
Log "PASS: mechanic/session/mastery/journey contracts retained"

$testSource=Join-Path $root "phase008r3b3-production-state.spec.ts"
$testTarget=Join-Path $root "tools\visual-regression\tests\learner-production-state.spec.ts"
if(-not(Test-Path $testSource)){throw "Production state test companion missing"}
Copy-Item $testSource $testTarget -Force
Log "PASS: production interaction regression specification installed"

Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Learner lint" "pnpm --filter learner-web lint"
Run "Learner production build" "pnpm --filter learner-web build"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"

Log ""
Log "PHASE 008R3B.3: PASS"
Log "Real ActivityPlayer lifecycle states are now observable without becoming state sources."
Log "Idle, retry, correct/completed and disabled states remain production-owned."
Log "No fabricated loading/error state was introduced."
Log "A Playwright production-interaction specification is installed for R3B.4 responsive QA."
Log "Learning mechanics, correctness, mastery and progression were not changed."
ZipLog
Write-Host "PHASE 008R3B.3: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
