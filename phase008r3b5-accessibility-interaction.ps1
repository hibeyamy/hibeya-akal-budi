Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path;$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff";$work=Join-Path $logs ("phase008r3b5-"+$stamp)
$log=Join-Path $work "phase008r3b5.log";$zip=Join-Path $logs ("phase008r3b5-accessibility-interaction-"+$stamp+".zip")
New-Item -ItemType Directory -Force -Path $work|Out-Null
function Log([string]$t=""){Add-Content $log $t -Encoding UTF8;Write-Host $t}
function Run([string]$l,[string]$c){Log "";Log ("==> "+$l);Log $c;$o=Join-Path $work "o.txt";$e=Join-Path $work "e.txt";$p=Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$c) -WorkingDirectory $root -Wait -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e;foreach($f in @($o,$e)){if(Test-Path $f){$x=Get-Content $f -Raw -ErrorAction SilentlyContinue;if($x){Log $x.TrimEnd()};Remove-Item $f -Force -ErrorAction SilentlyContinue}};if($p.ExitCode-ne 0){throw ($l+" failed with exit code "+$p.ExitCode)};Log ("PASS: "+$l)}
function ZipLog(){foreach($c in @("test-results","playwright-report")){$s=Join-Path $root $c;if(Test-Path $s){Copy-Item $s (Join-Path $work $c) -Recurse -Force -ErrorAction SilentlyContinue}};if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Log "";Log "PHASE 008R3B.5: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.5" -ForegroundColor Cyan
Write-Host "Accessibility + Interaction QA" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Run "Install reduced-motion production repair" "node phase008r3b5-patch.mjs"
Copy-Item (Join-Path $root "phase008r3b5-accessibility.spec.ts") (Join-Path $root "tools\visual-regression\tests\learner-accessibility.spec.ts") -Force
Log "PASS: accessibility regression installed"
Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Storybook production build" "pnpm storybook:build"
Run "Accessibility interaction regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-accessibility.spec.ts"
Run "Responsive production regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-responsive-production.spec.ts"
Run "Existing learner journey regression" "pnpm qa:journey"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Content reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Asset registry reproducibility" "node tools/assets/compile-commercial-registry.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Log "";Log "PHASE 008R3B.5: PASS"
Log "Axe baseline, keyboard activation, visible focus, live feedback, disabled completion state and reduced motion passed."
Log "Existing responsive and journey regressions remain green."
Log "Only learner choice reduced-motion behaviour was changed in production."
ZipLog
Write-Host "PHASE 008R3B.5: PASS" -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
