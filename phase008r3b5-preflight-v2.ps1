Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3b5-preflight-v2-"+$stamp)
$report=Join-Path $work "phase008r3b5-preflight-v2.txt"
$zip=Join-Path $logs ("phase008r3b5-accessibility-interaction-preflight-v2-"+$stamp+".zip")
New-Item -ItemType Directory -Force -Path $work|Out-Null
function Log([string]$t=""){Add-Content $report $t -Encoding UTF8;Write-Host $t}
function ZipLog(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
function Capture([string]$r){$s=Join-Path $root $r;if(Test-Path $s){Copy-Item $s (Join-Path $work ($r.Replace("\","__").Replace("/","__"))) -Force;Log ("CAPTURED: "+$r)}else{Log ("MISSING: "+$r)}}
trap{Log "";Log "PHASE 008R3B.5 PREFLIGHT V2: FAILED";Log ($_|Out-String);Log $_.ScriptStackTrace;ZipLog;Write-Host ("Diagnostic ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.5 PREFLIGHT V2" -ForegroundColor Cyan
Write-Host "Accessibility + Interaction QA Inspection" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Log ("Generated: "+(Get-Date).ToString("o"))
Log ("Repository: "+$root)

foreach($r in @(
"apps\learner-web\src\features\play\ActivityPlayer.tsx",
"apps\learner-web\src\index.css",
"apps\learner-web\package.json",
"apps\ui-storybook\.storybook\preview.ts",
"apps\ui-storybook\stories\LearnerJourney.stories.tsx",
"apps\ui-storybook\package.json",
"tools\visual-regression\playwright.config.ts",
"tools\visual-regression\tests\learner-responsive-production.spec.ts",
"tools\visual-regression\tests\learner-journey.spec.ts",
"tools\visual-regression\tests\production-assets.spec.ts",
"package.json"
)){Capture $r}

$roots=@((Join-Path $root "apps\learner-web\src"),(Join-Path $root "apps\ui-storybook"),(Join-Path $root "tools\visual-regression"))
$files=@()
foreach($sr in $roots){if(Test-Path $sr){$files+=@(Get-ChildItem $sr -Recurse -File -Include *.ts,*.tsx,*.css,*.json -ErrorAction SilentlyContinue|Where-Object{$_.FullName -notmatch "\\node_modules\\|\\dist\\|\\storybook-static\\|\\test-results\\|\\playwright-report\\"})}}

Log "";Log "===== ACCESSIBILITY DEPENDENCY DISCOVERY ====="
foreach($pkg in @((Join-Path $root "package.json"),(Join-Path $root "apps\learner-web\package.json"),(Join-Path $root "apps\ui-storybook\package.json"))){
 if(-not(Test-Path $pkg)){continue}
 $json=Get-Content $pkg -Raw|ConvertFrom-Json
 Log ("-- "+$pkg.Substring($root.Length).TrimStart("\")+" --")
 $deps=@()
 $p=$json.PSObject.Properties["dependencies"];if($null-ne$p -and $null-ne$p.Value){$deps+=@($p.Value.PSObject.Properties.Name)}
 $p=$json.PSObject.Properties["devDependencies"];if($null-ne$p -and $null-ne$p.Value){$deps+=@($p.Value.PSObject.Properties.Name)}
 foreach($n in @("@axe-core/playwright","axe-core","@storybook/addon-a11y","eslint-plugin-jsx-a11y","@testing-library/react","@testing-library/user-event","playwright","@playwright/test")){if($deps -contains $n){Log ("FOUND: "+$n)}}
}

Log "";Log "===== CURRENT A11Y / INTERACTION CONTRACTS ====="
foreach($n in @("aria-live","aria-atomic","aria-pressed","aria-label","aria-hidden","disabled=","focus-visible","focus:ring","tabIndex","role=","touch-manipulation","min-h-14","min-h-40","active:scale","prefers-reduced-motion","motion-reduce","outline-none","data-feedback-state","data-activity-state")){
 $hits=@($files|Select-String -SimpleMatch -Pattern $n -Context 2,6 -ErrorAction SilentlyContinue)
 Log "";Log ("-- "+$n+" | hits="+$hits.Count+" --");foreach($h in $hits){Log $h.ToString()}
}
Log "";Log "===== PLAYWRIGHT A11Y / KEYBOARD COVERAGE ====="
foreach($n in @("keyboard.press","toBeFocused","aria-live","axe","accessibility","disabled","focus","boundingBox","56")){
 $hits=@($files|Select-String -SimpleMatch -Pattern $n -Context 2,8 -ErrorAction SilentlyContinue)
 Log "";Log ("-- "+$n+" | hits="+$hits.Count+" --");foreach($h in $hits){Log $h.ToString()}
}

Log "";Log "===== PHASE 008R3B.5 DECISION RULES ====="
Log "1. Reuse existing Playwright and Storybook infrastructure."
Log "2. Add no accessibility dependency if current tooling can verify required contracts."
Log "3. Reuse axe/Storybook a11y only if already installed."
Log "4. Keyboard QA must exercise the real learner activity integration used by R3B.4."
Log "5. Correct/incorrect feedback must remain understandable without colour alone."
Log "6. Disabled choices after completion must be non-interactive by keyboard and pointer."
Log "7. Focus-visible styling must remain observable during keyboard interaction."
Log "8. aria-live feedback should announce committed answer feedback without duplicate/stale state."
Log "9. Retain the existing >=56px learner touch-target standard."
Log "10. Add reduced-motion treatment only where current motion justifies it."
Log "11. Do not fabricate accessibility-only correctness or learner state."
Log "12. Do not change curriculum, mechanics, mastery, progression or production assets."

Log "";Log "PHASE 008R3B.5 PREFLIGHT V2: PASS"
Log "No learner source, Storybook source, test source, dependency, content, asset or lockfile was modified."
ZipLog
Write-Host "PHASE 008R3B.5 PREFLIGHT V2: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: "+$zip) -ForegroundColor Cyan
