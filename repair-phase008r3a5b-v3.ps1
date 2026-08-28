Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs ("phase008r3a5b-repair-v3-" + $stamp)
$log = Join-Path $work "phase008r3a5b-repair-v3.log"
$zip = Join-Path $logs ("phase008r3a5b-repair-v3-" + $stamp + ".zip")
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
  Add-Content -Path $log -Value $Text -Encoding UTF8
  Write-Host $Text
}
function Run([string]$Label,[string]$Command) {
  Log ""; Log ("==> " + $Label); Log $Command
  $o = Join-Path $work "stdout.txt"
  $e = Join-Path $work "stderr.txt"
  $p = Start-Process "cmd.exe" -ArgumentList @("/d","/s","/c",$Command) -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
  foreach ($f in @($o,$e)) {
    if (Test-Path $f) {
      $t = Get-Content -Path $f -Raw -ErrorAction SilentlyContinue
      if ($t) { Log $t.TrimEnd() }
      Remove-Item $f -Force -ErrorAction SilentlyContinue
    }
  }
  if ($p.ExitCode -ne 0) { throw ($Label + " failed with exit code " + $p.ExitCode) }
  Log ("PASS: " + $Label)
}
function ZipLog() {
  if (Test-Path $zip) { Remove-Item $zip -Force }
  Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}
trap {
  Log ""; Log "PHASE 008R3A.5B REPAIR V3: FAILED"; Log ($_ | Out-String); Log $_.ScriptStackTrace
  ZipLog
  Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Yellow
  exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.5B REPAIR V3" -ForegroundColor Cyan
Write-Host "UTF-8 BOM Compatibility + Validation Resume" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$source = Join-Path $root "phase008r3a5b-inspect-candidates-v3.mjs"
$target = Join-Path $root "tools\assets\inspect-fruit-candidates.mjs"
if (-not (Test-Path $source)) { throw ("Missing companion: " + $source) }
Copy-Item $source $target -Force
Log "PASS: BOM-tolerant candidate inspector installed"
Log "PASS: existing review records left unchanged"

Run "Verify project-local Sharp" "node -e ""import('sharp').then(()=>console.log('sharp available')).catch(e=>{console.error(e);process.exit(1)})"""
Run "Inspect staged fruit PNG candidates" "node tools/assets/inspect-fruit-candidates.mjs"

$runtimeText = ""
foreach ($relative in @(
  "packages\assets\src\generated\commercialRegistry.generated.ts",
  "packages\assets\src\commercial.ts",
  "packages\assets\src\index.ts"
)) {
  $full = Join-Path $root $relative
  if (Test-Path $full) { $runtimeText += (Get-Content -Path $full -Raw) + "`n" }
}
foreach ($id in @("apple-red","apple-green","banana-yellow")) {
  if ($runtimeText -match [Regex]::Escape("./" + $id + ".webp")) {
    throw ("Fruit WebP leaked into runtime before promotion: " + $id)
  }
}
Log "PASS: fruit candidates remain outside production runtime"

Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Raster pipeline reproducibility" "node tools/assets/build-raster-assets.mjs --check"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.5B REPAIR V3: PASS"
Log "UTF-8 BOM compatibility verified."
Log "Human visual approvals remain recorded."
Log "All staged fruit candidates pass technical inspection."
Log "No fruit asset has been promoted to production."
Log "Next: Phase 008R3A.5C controlled promotion."
ZipLog

Write-Host "PHASE 008R3A.5B REPAIR V3: PASS" -ForegroundColor Green
Write-Host ("Diagnostic ZIP: " + $zip) -ForegroundColor Cyan
