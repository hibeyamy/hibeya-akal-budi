Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path;$logs=Join-Path $root "tools\dev\logs";New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff";$work=Join-Path $logs ("phase008r3b6-promotion-"+$stamp);$log=Join-Path $work "promotion.log";$zip=Join-Path $logs ("phase008r3b6-governed-promotion-"+$stamp+".zip");New-Item -ItemType Directory -Force -Path $work|Out-Null
function L([string]$t=""){Add-Content $log $t -Encoding UTF8;Write-Host $t}
function R([string]$label,[string]$cmd){L "";L ("==> "+$label);$o=Join-Path $work "out";$e=Join-Path $work "err";$p=Start-Process cmd.exe -ArgumentList @("/d","/s","/c",$cmd) -WorkingDirectory $root -Wait -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e;foreach($f in @($o,$e)){if(Test-Path $f){$x=Get-Content $f -Raw -ErrorAction SilentlyContinue;if($x){L $x.TrimEnd()};Remove-Item $f -Force}};if($p.ExitCode-ne 0){throw ($label+" failed with exit code "+$p.ExitCode)};L ("PASS: "+$label)}
function Z(){foreach($c in @("test-results","playwright-report")){$s=Join-Path $root $c;if(Test-Path $s){Copy-Item $s (Join-Path $work $c) -Recurse -Force -ErrorAction SilentlyContinue}};if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{L "";L "R3B.6 GOVERNED PROMOTION: FAILED";L ($_|Out-String);L $_.ScriptStackTrace;Z;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - R3B.6 GOVERNED PROMOTION" -ForegroundColor Cyan
Write-Host "beza-bunga-raya-001" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
L "Human approval received: visual, originality, cultural suitability and age suitability."
R "Record approval and promote activity" "node phase008r3b6-promote-beza-bunga-raya.mjs"
R "Verify promotion metadata" "node phase008r3b6-verify-promotion.mjs"
R "Compile content" "pnpm content:compile"
R "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
R "Content sequencing validation" "pnpm content:sequence:validate"
R "Content eligibility validation" "pnpm content:eligibility:validate"
R "Content coverage validation" "pnpm content:coverage:validate"
R "R3B.6 content-asset integration audit" "node tools/assets/audit-content-runtime-integration.mjs"
R "Asset registry reproducibility" "pnpm assets:runtime:check"
R "Asset runtime validation" "pnpm assets:runtime:validate"
R "Commercial asset validation" "pnpm assets:commercial:validate"
R "Runtime format validation" "pnpm assets:formats:validate"
R "Learner typecheck" "pnpm --filter learner-web typecheck"
R "Storybook production build" "pnpm storybook:build"
R "Responsive production regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-responsive-production.spec.ts"
R "Accessibility interaction regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-accessibility.spec.ts"
R "Learner journey regression" "pnpm qa:journey"
R "Frozen lockfile" "pnpm install --frozen-lockfile"
L "";L "R3B.6 GOVERNED PROMOTION: PASS";L "beza-bunga-raya-001 is reviewed, active, enabled and validated through the complete production boundary.";Z
Write-Host "R3B.6 GOVERNED PROMOTION: PASS" -ForegroundColor Green;Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
