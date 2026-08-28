Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3a5c-" + $stamp)
$log = Join-Path $work "phase008r3a5c.log"
$zip = Join-Path $logs ("phase008r3a5c-controlled-promotion-" + $stamp + ".zip")
$backup = Join-Path $work "before"
New-Item -ItemType Directory -Force -Path $work,$backup | Out-Null

function Log([string]$Text = "") {
  Add-Content -Path $log -Value $Text -Encoding UTF8
  Write-Host $Text
}
function Run([string]$Label,[string]$Command) {
  Log ""; Log ("==> " + $Label); Log $Command
  $o = Join-Path $work "stdout.txt"; $e = Join-Path $work "stderr.txt"
  $p = Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$Command) -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
  foreach ($f in @($o,$e)) {
    if (Test-Path $f) {
      $t = Get-Content $f -Raw -ErrorAction SilentlyContinue
      if ($t) { Log $t.TrimEnd() }
      Remove-Item $f -Force -ErrorAction SilentlyContinue
    }
  }
  if ($p.ExitCode -ne 0) { throw ($Label + " failed with exit code " + $p.ExitCode) }
  Log ("PASS: " + $Label)
}
function Backup-File([string]$Relative) {
  $src = Join-Path $root $Relative
  if (Test-Path $src) {
    $safe = $Relative.Replace("\","__").Replace("/","__")
    Copy-Item $src (Join-Path $backup $safe) -Force
  }
}
function Save-Zip {
  if (Test-Path $zip) { Remove-Item $zip -Force }
  Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}
trap {
  Log ""; Log "PHASE 008R3A.5C: FAILED"; Log ($_ | Out-String); Log $_.ScriptStackTrace
  Save-Zip
  Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
  Write-Host "Repository backup snapshots are inside the ZIP." -ForegroundColor Yellow
  exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.5C" -ForegroundColor Cyan
Write-Host "Controlled Fruit Promotion" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

foreach ($f in @(
  "packages\assets\source\raster-assets.json",
  "packages\assets\source\visual-replacement-plan.json",
  "packages\assets\source\review\fruit\apple-red.review.json",
  "packages\assets\source\review\fruit\apple-green.review.json",
  "packages\assets\source\review\fruit\banana-yellow.review.json",
  "assets\manifests\apple-red.json",
  "assets\manifests\apple-green.json",
  "assets\manifests\banana-yellow.json",
  "packages\assets\src\generated\commercialRegistry.generated.ts"
)) { Backup-File $f }
Log "PASS: before-state snapshots captured"

$promoterSource = Join-Path $root "phase008r3a5c-promote-fruit.mjs"
$verifySource = Join-Path $root "phase008r3a5c-verify-fruit.mjs"
if (-not (Test-Path $promoterSource)) { throw "Missing promotion companion script" }
if (-not (Test-Path $verifySource)) { throw "Missing verification companion script" }

Copy-Item $promoterSource (Join-Path $root "tools\assets\promote-fruit-assets.mjs") -Force
Copy-Item $verifySource (Join-Path $root "tools\assets\verify-fruit-promotion.mjs") -Force

Run "Verify frozen lockfile before mutation" "pnpm install --frozen-lockfile"
Run "Verify current raster reproducibility" "node tools/assets/build-raster-assets.mjs --check"
Run "Apply reviewed fruit promotion contracts" "node tools/assets/promote-fruit-assets.mjs"
Run "Generate production WebP derivatives" "node tools/assets/build-raster-assets.mjs"
Run "Verify deterministic raster output" "node tools/assets/build-raster-assets.mjs --check"
Run "Compile commercial registry" "node tools/assets/compile-commercial-registry.mjs"
Run "Verify commercial registry reproducibility" "node tools/assets/compile-commercial-registry.mjs --check"
Run "Verify controlled fruit promotion" "node tools/assets/verify-fruit-promotion.mjs"

# Move obsolete generated SVG delivery files out of runtime only after the registry cutover passes.
$legacyDir = Join-Path $root "packages\assets\source\legacy\fruit"
New-Item -ItemType Directory -Force -Path $legacyDir | Out-Null
foreach ($id in @("apple-red","apple-green","banana-yellow")) {
  $svg = Join-Path $root ("packages\assets\src\generated\" + $id + ".svg")
  if (Test-Path $svg) {
    Move-Item $svg (Join-Path $legacyDir ($id + ".svg")) -Force
    Log ("RETIRED DELIVERY SVG: " + $id)
  }
}

Run "Verify registry after SVG retirement" "node tools/assets/verify-fruit-promotion.mjs"
Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Storybook production build" "pnpm --filter ui-storybook build-storybook"
Run "Content compiler reproducibility" "node tools/content-compiler/compile.mjs --check"
Run "Frozen lockfile after promotion" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.5C: PASS"
Log "Reviewed fruit PNGs are authoritative masters."
Log "Fruit WebPs are production runtime delivery assets."
Log "Commercial registry no longer exposes fruit SVGs."
Log "Former generated fruit SVGs are retained under source/legacy/fruit."
Log "Semantic asset IDs and learning content remain unchanged."
Log "Next: Phase 008R3A.6 production visual regression and asset governance close-out."

Save-Zip
Write-Host "PHASE 008R3A.5C: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
