Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path;$logs=Join-Path $root "tools\dev\logs";New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff";$work=Join-Path $logs ("phase008r3b6-v4-"+$stamp);$log=Join-Path $work "continuation.log";$zip=Join-Path $logs ("phase008r3b6-v4-continuation-"+$stamp+".zip");New-Item -ItemType Directory -Force -Path $work|Out-Null
function Write-Log([string]$Text=""){Add-Content $log $Text -Encoding UTF8;Write-Host $Text}
function Invoke-Step([string]$Label,[string]$Command){Write-Log "";Write-Log ("==> "+$Label);Write-Log $Command;$o=Join-Path $work "out";$e=Join-Path $work "err";$p=Start-Process cmd.exe -ArgumentList @("/d","/s","/c",$Command) -WorkingDirectory $root -Wait -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e;foreach($f in @($o,$e)){if(Test-Path $f){$x=Get-Content $f -Raw -ErrorAction SilentlyContinue;if($x){Write-Log $x.TrimEnd()};Remove-Item $f -Force}};if($p.ExitCode-ne 0){throw ($Label+" failed with exit code "+$p.ExitCode)};Write-Log ("PASS: "+$Label)}
function Save-Zip{foreach($c in @("test-results","playwright-report")){$s=Join-Path $root $c;if(Test-Path $s){Copy-Item $s (Join-Path $work $c) -Recurse -Force -ErrorAction SilentlyContinue}};if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Write-Log "";Write-Log "R3B.6 V4 CONTINUATION: FAILED";Write-Log ($_|Out-String);Write-Log $_.ScriptStackTrace;Save-Zip;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}
Write-Host "HIBEYA AKAL BUDI - R3B.6 V4 CONTINUATION" -ForegroundColor Cyan
Invoke-Step "Verify existing governed promotion" "node phase008r3b6-v4-verify-promoted-state.mjs"
Invoke-Step "Compile content" "node tools/content-compiler/compile.mjs"
Invoke-Step "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Invoke-Step "Content sequencing validation" "pnpm content:sequence:validate"
Invoke-Step "Content eligibility validation" "pnpm content:eligibility:validate"
Invoke-Step "Content coverage validation" "pnpm content:coverage:validate"
Invoke-Step "R3B.6 integration audit" "node tools/assets/audit-content-runtime-integration.mjs"
Invoke-Step "Asset registry reproducibility" "pnpm assets:runtime:check"
Invoke-Step "Asset runtime validation" "pnpm assets:runtime:validate"
Invoke-Step "Commercial asset validation" "pnpm assets:commercial:validate"
Invoke-Step "Runtime format validation" "pnpm assets:formats:validate"
Invoke-Step "Learner typecheck" "pnpm --filter learner-web typecheck"
Invoke-Step "Storybook production build" "pnpm storybook:build"
Invoke-Step "Responsive regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-responsive-production.spec.ts"
Invoke-Step "Accessibility regression" "pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-accessibility.spec.ts"
Invoke-Step "Learner journey regression" "pnpm qa:journey"
Invoke-Step "Frozen lockfile" "pnpm install --frozen-lockfile"
Write-Log "";Write-Log "R3B.6 V4 CONTINUATION: PASS";Write-Log "Existing promotion intact; coverage, integration and regression boundary passed; promotion metadata was not rewritten.";Save-Zip
Write-Host "R3B.6 V4 CONTINUATION: PASS" -ForegroundColor Green;Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
