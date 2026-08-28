Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$root=(Get-Location).Path
$logs=Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs|Out-Null
$stamp=Get-Date -Format "yyyyMMdd-HHmmssfff"
$work=Join-Path $logs ("phase008r3b1-preflight-"+$stamp)
$zip=Join-Path $logs ("phase008r3b1-production-integration-preflight-"+$stamp+".zip")
New-Item -ItemType Directory -Force -Path $work|Out-Null

function Copy-Evidence([string]$relative){
 $src=Join-Path $root $relative
 if(Test-Path $src){
   $name=$relative.Replace("\","__").Replace("/","__")
   Copy-Item $src (Join-Path $work $name) -Force
   Write-Host ("CAPTURED: "+$relative)
 }else{
   Add-Content (Join-Path $work "missing.txt") ("MISSING: "+$relative) -Encoding UTF8
 }
}
function Save-Zip(){if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force}
trap{Add-Content (Join-Path $work "failure.txt") ($_|Out-String) -Encoding UTF8;Save-Zip;Write-Host ("ZIP: "+$zip) -ForegroundColor Yellow;exit 1}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3B.1 PREFLIGHT" -ForegroundColor Cyan
Write-Host "Exact Learner Visual Boundary Capture" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach($f in @(
 "apps\learner-web\src\features\play\ActivityPlayer.tsx",
 "apps\learner-web\src\features\play\activityRegistry.ts",
 "apps\learner-web\src\features\play\ActivityPlayerAdapter.tsx",
 "apps\learner-web\src\journey\LearnerActivityBridge.tsx",
 "apps\ui-storybook\stories\DraftActivityVisualReview.stories.tsx",
 "apps\ui-storybook\stories\ProductionVisualBaseline.stories.tsx",
 "packages\assets\src\index.ts",
 "packages\assets\src\metadata.ts",
 "packages\content-library\src\activities\warnaMerah001.ts",
 "packages\content-library\src\activities\warnaBungaRaya001.ts",
 "tools\visual-regression\tests\production-assets.spec.ts",
 "apps\learner-web\package.json",
 "apps\ui-storybook\package.json",
 "package.json"
)){Copy-Evidence $f}

# Capture matching content files even if exact paths differ.
$content=Join-Path $root "packages\content-library\src"
if(Test-Path $content){
 Get-ChildItem $content -Recurse -File -Include *.ts,*.tsx |
   Select-String -Pattern "warna-merah-001|warna-bunga-raya-001|apple-red|apple-green|banana-yellow|hibiscus-red|hibiscus-yellow|hibiscus-purple" |
   Select-Object -ExpandProperty Path -Unique |
   ForEach-Object{
     $rel=$_.Substring($root.Length).TrimStart("\")
     Copy-Evidence $rel
   }
}

$summary=Join-Path $work "README-PREFLIGHT.txt"
@"
PHASE 008R3B.1 EXACT BOUNDARY CAPTURE
Generated: $(Get-Date -Format o)

Purpose:
- capture exact current learner renderer and its adjacent contracts;
- avoid regex/line-number assumptions before modifying ActivityPlayer;
- preserve learning logic, sequencing, mastery and progression;
- no repository source was modified.

Observed from 008R3B preflight:
- ActivityPlayer is the production learner visual boundary.
- Both supported activities use implementationKey colour-choice-v1.
- ActivityPlayer already branches on asset.type and renders image asset.value.
- No learner emoji/placeholder fallback was found by semantic search.
- The only placeholder hit was the activation-code input and is unrelated.
- Production assets are governed through commercial getAsset() overrides.
"@ | Set-Content $summary -Encoding UTF8

Save-Zip
Write-Host ""
Write-Host "PHASE 008R3B.1 PREFLIGHT: PASS" -ForegroundColor Green
Write-Host "No repository source was modified." -ForegroundColor Green
Write-Host ("ZIP: "+$zip) -ForegroundColor Cyan
