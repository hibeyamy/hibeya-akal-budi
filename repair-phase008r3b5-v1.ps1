Set-StrictMode -Version Latest
$ErrorActionPreference="Stop";$root=(Get-Location).Path;$logs=Join-Path $root "tools\dev\logs";New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff";$work=Join-Path $logs ("phase008r3b5-repair-v1-"+$stamp);$log=Join-Path $work "repair.log";$zip=Join-Path $logs ("phase008r3b5-repair-v1-"+$stamp+".zip");New-Item -ItemType Directory -Force -Path $work|Out-Null
function L([string]$t=""){Add-Content $log $t -Encoding UTF8;Write-Host $t}
function R([string]$n,[string]$c){L "";L ("==> "+$n);$o=Join-Path $work "o";$e=Join-Path $work "e";$p=Start-Process cmd.exe -ArgumentList @("/d","/s","/c",$c) -WorkingDirectory $root -Wait -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e;foreach($f in @($o,$e)){if(Test-Path $f){$x=Get-Content $f -Raw;if($x){L $x.TrimEnd()};Remove-Item $f -Force}};if($p.ExitCode-ne 0){throw ($n+" failed "+$p.ExitCode)};L ("PASS: "+$n)}
function Z(){foreach($c in @("test-results","playwright-report")){$s=Join-Path $root $c;if(Test-Path $s){Copy-Item $s (Join-Path $work $c) -Recurse -Force -ErrorAction SilentlyContinue}};if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{L "";L "PHASE 008R3B.5 REPAIR V1: FAILED";L ($_|Out-String);L $_.ScriptStackTrace;Z;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.5 REPAIR V1" -ForegroundColor Cyan
R "Repair nested main landmark" "node repair-phase008r3b5-v1-patch.mjs"
Copy-Item (Join-Path $root "repair-phase008r3b5-v1-accessibility.spec.ts") (Join-Path $root "tools\visual-regression\tests\learner-accessibility.spec.ts") -Force
R "Learner typecheck" "pnpm --filter learner-web typecheck"
R "Storybook production build" "pnpm storybook:build"
R "Accessibility interaction regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-accessibility.spec.ts"
R "Responsive regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-responsive-production.spec.ts"
R "Journey regression" "pnpm qa:journey"
R "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
R "Content reproducibility" "node tools/content-compiler/compile.mjs --check"
R "Asset registry reproducibility" "node tools/assets/compile-commercial-registry.mjs --check"
R "Frozen lockfile" "pnpm install --frozen-lockfile"
L "";L "PHASE 008R3B.5 REPAIR V1: PASS";L "Nested main landmark repaired; keyboard focus uses real Tab traversal; reduced-motion assertion uses effective-zero tolerance.";Z
Write-Host "PHASE 008R3B.5 REPAIR V1: PASS" -ForegroundColor Green;Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
