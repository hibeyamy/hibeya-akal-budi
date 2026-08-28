Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3a6-" + $stamp)
$log = Join-Path $work "phase008r3a6.log"
$zip = Join-Path $logs ("phase008r3a6-production-visual-governance-" + $stamp + ".zip")
$backup = Join-Path $work "before"
New-Item -ItemType Directory -Force -Path $work,$backup | Out-Null

function Log([string]$Text=""){Add-Content $log $Text -Encoding UTF8;Write-Host $Text}
function Run([string]$Label,[string]$Command){
 Log "";Log ("==> "+$Label);Log $Command
 $o=Join-Path $work "stdout.txt";$e=Join-Path $work "stderr.txt"
 $p=Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$Command) -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
 foreach($f in @($o,$e)){if(Test-Path $f){$t=Get-Content $f -Raw -ErrorAction SilentlyContinue;if($t){Log $t.TrimEnd()};Remove-Item $f -Force -ErrorAction SilentlyContinue}}
 if($p.ExitCode -ne 0){throw ($Label+" failed with exit code "+$p.ExitCode)}
 Log ("PASS: "+$Label)
}
function Save-Zip(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Log "";Log "PHASE 008R3A.6: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;Save-Zip;Write-Host ("Diagnostic ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.6" -ForegroundColor Cyan
Write-Host "Production Visual Regression + Governance Close-Out" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach($f in @(
 "packages\assets\src\metadata.ts",
 "packages\assets\source\asset-migration.json",
 "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx",
 "apps\parent-web\src\App.tsx"
)){
 $src=Join-Path $root $f
 if(Test-Path $src){Copy-Item $src (Join-Path $backup ($f.Replace("\","__").Replace("/","__"))) -Force}
}
Log "PASS: before-state snapshots captured"

Copy-Item (Join-Path $root "phase008r3a6-metadata.ts") (Join-Path $root "packages\assets\src\metadata.ts") -Force
Copy-Item (Join-Path $root "phase008r3a6-production-story.tsx") (Join-Path $root "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx") -Force
Copy-Item (Join-Path $root "phase008r3a6-production-assets.spec.ts") (Join-Path $root "tools\visual-regression\tests\production-assets.spec.ts") -Force
Copy-Item (Join-Path $root "phase008r3a6-closeout.mjs") (Join-Path $root "tools\assets\closeout-asset-governance.mjs") -Force
Log "PASS: close-out contracts installed"

Run "Update migration audit and known encoding defects" "node tools/assets/closeout-asset-governance.mjs"
Run "Raster reproducibility" "node tools/assets/build-raster-assets.mjs --check"
Run "Commercial registry reproducibility" "node tools/assets/compile-commercial-registry.mjs --check"
Run "Controlled fruit promotion verification" "node tools/assets/verify-fruit-promotion.mjs"
Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Parent web typecheck" "pnpm --filter parent-web typecheck"
Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Storybook production build" "pnpm --filter ui-storybook build-storybook"
Run "Production asset responsive visual regression" "pnpm --dir tools/visual-regression exec playwright test tests/production-assets.spec.ts"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.6: PASS"
Log "All six rich learning illustrations are governed PNG-master/WebP-delivery assets."
Log "Fruit and hibiscus metadata now reflect approved production state."
Log "Responsive production visual checks passed at mobile, tablet and desktop sizes."
Log "Legacy SVGs remain archived outside runtime delivery."
Log "Asset migration audit now covers all six assets."
Log "Known parent-web dash mojibake was normalised."
Log "No curriculum, activity sequencing, mastery or progression rule was changed."
Save-Zip
Write-Host "PHASE 008R3A.6: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: "+$zip) -ForegroundColor Cyan
