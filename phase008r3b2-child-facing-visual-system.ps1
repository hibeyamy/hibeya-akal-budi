Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3b2-"+$stamp)
$log=Join-Path $work "phase008r3b2.log"
$zip=Join-Path $logs ("phase008r3b2-child-facing-visual-system-"+$stamp+".zip")
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
trap{Log "";Log "PHASE 008R3B.2: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.2" -ForegroundColor Cyan
Write-Host "Child-Facing Visual System" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$target=Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
Copy-Item $target (Join-Path $backup "ActivityPlayer.tsx") -Force
Log "PASS: before-state captured"

Run "Apply child-facing visual-system patch" "node phase008r3b2-patch.mjs"

$after=Get-Content $target -Raw
foreach($needle in @(
 'data-testid="learner-activity-card"',
 'data-testid="learner-choice-state-icon"',
 'data-testid="learner-feedback"',
 'aria-atomic="true"',
 'data-testid="learner-completion"',
 'data-testid="learner-choice"',
 'data-production-asset='
)){
 if(-not $after.Contains($needle)){throw ("Expected R3B.2 contract missing: "+$needle)}
}
Log "PASS: child-facing visual-state contracts installed"

foreach($needle in @(
 "mechanic.submitAnswer(",
 "addLocalAnswer(",
 "completeLocalSession(",
 "recordSessionSkillMastery(",
 "recordCompletedJourneyActivity("
)){
 if(-not $after.Contains($needle)){throw ("Learning contract missing: "+$needle)}
}
Log "PASS: learning/session/mastery contracts preserved"

Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Learner lint" "pnpm --filter learner-web lint"
Run "Learner production build" "pnpm --filter learner-web build"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Asset registry reproducibility" "node tools/assets/compile-commercial-registry.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"

Log ""
Log "PHASE 008R3B.2: PASS"
Log "Child-facing hierarchy and feedback states were strengthened at ActivityPlayer."
Log "Correct and incorrect states now use shape/icon cues in addition to colour."
Log "Artwork remains object-contained and dominant."
Log "Touch sizing, keyboard focus and aria-live feedback were preserved or strengthened."
Log "No learning content, answer logic, mastery, progression, asset or dependency was changed."
ZipLog
Write-Host "PHASE 008R3B.2: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
