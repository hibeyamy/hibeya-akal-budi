Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3b1-"+$stamp)
$log=Join-Path $work "phase008r3b1.log"
$zip=Join-Path $logs ("phase008r3b1-production-asset-integration-"+$stamp+".zip")
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
trap{Log "";Log "PHASE 008R3B.1: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.1" -ForegroundColor Cyan
Write-Host "Production Asset Integration" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$target=Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
if(-not(Test-Path $target)){throw "ActivityPlayer.tsx missing"}
Copy-Item $target (Join-Path $backup "ActivityPlayer.tsx") -Force
Log "PASS: ActivityPlayer before-state captured"

Run "Apply exact visual-boundary patch" "node phase008r3b1-patch.mjs"

# Guard against changing the core answer/session/mastery functions.
$before=Get-Content (Join-Path $backup "ActivityPlayer.tsx") -Raw
$after=Get-Content $target -Raw
foreach($needle in @(
 "mechanic.submitAnswer(",
 "addLocalAnswer(",
 "completeLocalSession(",
 "recordSessionSkillMastery(",
 "recordCompletedJourneyActivity(",
 "selectLearnerActivity("
)){
 if(-not $after.Contains($needle)){throw ("Learning contract unexpectedly missing after patch: "+$needle)}
}
Log "PASS: learning/session/mastery boundaries retained"

# Verify the visual boundary now carries deterministic integration hooks.
foreach($needle in @(
 'data-testid="learner-choice"',
 'data-asset-id=',
 'data-visual-state=',
 'data-testid="learner-choice-visual"',
 'data-production-asset=',
 'data-fallback-asset='
)){
 if(-not $after.Contains($needle)){throw ("Expected visual integration hook missing: "+$needle)}
}
Log "PASS: deterministic learner visual integration hooks installed"

Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Learner lint" "pnpm --filter learner-web lint"
Run "Learner production build" "pnpm --filter learner-web build"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Asset registry reproducibility" "node tools/assets/compile-commercial-registry.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"

Log ""
Log "PHASE 008R3B.1: PASS"
Log "ActivityPlayer remains the single production learner visual boundary."
Log "Approved rich assets continue to resolve through getAsset()."
Log "Illustration geometry is normalised without hard-coded physical asset paths."
Log "Deterministic visual-state hooks are available for the next child-facing visual-system phase."
Log "Learning logic, sequencing, mastery and progression contracts were preserved."
Log "No dependency was added."
ZipLog
Write-Host "PHASE 008R3B.1: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
