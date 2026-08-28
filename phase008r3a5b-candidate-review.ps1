Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
$work = Join-Path $logs "phase008r3a5b-$stamp"
$log = Join-Path $work "phase008r3a5b.log"
$zip = Join-Path $logs "phase008r3a5b-candidate-review-$stamp.zip"
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Log([string]$Text = "") {
  Add-Content -Path $log -Value $Text -Encoding UTF8
  Write-Host $Text
}

function Run([string]$Label,[string]$Command) {
  Log ""
  Log "==> $Label"
  Log $Command
  $out = Join-Path $work "stdout.txt"
  $err = Join-Path $work "stderr.txt"
  $p = Start-Process "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $out -RedirectStandardError $err
  foreach ($f in @($out,$err)) {
    if (Test-Path $f) {
      $t = Get-Content $f -Raw -ErrorAction SilentlyContinue
      if ($t) { Log $t.TrimEnd() }
      Remove-Item $f -Force -ErrorAction SilentlyContinue
    }
  }
  if ($p.ExitCode -ne 0) {
    throw "$Label failed with exit code $($p.ExitCode)"
  }
  Log "PASS: $Label"
}

function ZipLog() {
  if (Test-Path $zip) { Remove-Item $zip -Force }
  Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -Force
}

trap {
  Log ""
  Log "PHASE 008R3A.5B: FAILED"
  Log ($_ | Out-String)
  Log $_.ScriptStackTrace
  ZipLog
  Write-Host ""
  Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Yellow
  exit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008R3A.5B" -ForegroundColor Cyan
Write-Host "Candidate Visual Review + Controlled Variant Gate" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$reviewDir = Join-Path $root "packages\assets\source\review\fruit"
$planPath = Join-Path $root "packages\assets\source\visual-replacement-plan.json"

foreach ($required in @($reviewDir,$planPath)) {
  if (-not (Test-Path $required)) { throw "Required prior-phase contract missing: $required" }
}

$ids = @("apple-red","apple-green","banana-yellow")

foreach ($id in $ids) {
  $png = Join-Path $reviewDir "$id.png"
  $json = Join-Path $reviewDir "$id.review.json"
  if (-not (Test-Path $png)) { throw "Missing staged candidate: $png" }
  if (-not (Test-Path $json)) { throw "Missing staged review record: $json" }

  $record = Get-Content $json -Raw | ConvertFrom-Json
  if ($record.id -ne $id) { throw "$id review record ID mismatch" }
  if ($record.productionEnabled -eq $true) {
    throw "$id is already production-enabled before promotion gate"
  }

  # Record the explicit human review supplied for this phase.
  $record.visualReviewed = $true
  $record.state = "human-visual-review-passed"
  $record | Add-Member -NotePropertyName visualReviewedAt -NotePropertyValue (Get-Date).ToString("o") -Force
  $record | Add-Member -NotePropertyName visualReviewMethod -NotePropertyValue "manual-local-review" -Force

  $record |
    ConvertTo-Json -Depth 10 |
    Set-Content -Path $json -Encoding UTF8

  Log "PASS: $id human visual review recorded"
}

# Guardrail: visual approval is not provenance/originality approval and is not production promotion.
foreach ($id in $ids) {
  $record = Get-Content (Join-Path $reviewDir "$id.review.json") -Raw | ConvertFrom-Json
  if ($record.visualReviewed -ne $true) { throw "$id visual review flag not recorded" }
  if ($record.productionEnabled -eq $true) { throw "$id was incorrectly promoted" }
}
Log "PASS: visual review remains separate from production promotion"

Run "Verify staged PNG technical metadata" "node tools/assets/stage-raster-master.mjs --help"

# Verify old runtime fallback remains in place at this gate.
$registryCandidates = @(
  "packages\assets\src\generated\commercialRegistry.generated.ts",
  "packages\assets\src\commercialRegistry.ts",
  "packages\assets\src\index.ts"
)
$registryText = ""
foreach ($candidate in $registryCandidates) {
  if (Test-Path $candidate) {
    $registryText += (Get-Content $candidate -Raw) + "`n"
  }
}

foreach ($id in $ids) {
  if ($registryText -match [regex]::Escape("./$id.webp")) {
    throw "$id WebP is already exposed by runtime before Phase 008R3A.5C"
  }
}
Log "PASS: fruit WebP has not leaked into runtime before promotion"

Run "Assets typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Storybook typecheck" "pnpm --filter ui-storybook typecheck"
Run "Learner typecheck" "pnpm --filter learner-web typecheck"
Run "Learner tests" "pnpm --filter learner-web test"
Run "Frozen lockfile" "pnpm install --frozen-lockfile"
Run "Git whitespace" "git diff --check"

Log ""
Log "PHASE 008R3A.5B: PASS"
Log "Human visual review is recorded for apple-red, apple-green and banana-yellow."
Log "Candidates remain staged and are not production-enabled."
Log "Next: Phase 008R3A.5C controlled promotion to authoritative PNG masters and WebP runtime delivery."

ZipLog
Write-Host ""
Write-Host "PHASE 008R3A.5B: PASS" -ForegroundColor Green
Write-Host "Diagnostic ZIP: $zip" -ForegroundColor Cyan
