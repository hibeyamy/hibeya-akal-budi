Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root =
  (Get-Location).Path

$logs =
  Join-Path
    $root
    "tools\dev\logs"

New-Item `
  -ItemType Directory `
  -Force `
  -Path $logs |
  Out-Null

$stamp =
  Get-Date `
    -Format "yyyyMMdd-HHmmssfff"

$work =
  Join-Path
    $logs
    "phase008r3a5b-repair-v1-$stamp"

$log =
  Join-Path
    $work
    "phase008r3a5b-repair-v1.log"

$zip =
  Join-Path
    $logs
    "phase008r3a5b-repair-v1-$stamp.zip"

New-Item `
  -ItemType Directory `
  -Force `
  -Path $work |
  Out-Null


function Log(
  [string]$Text = ""
) {
  Add-Content `
    -Path $log `
    -Value $Text `
    -Encoding UTF8

  Write-Host $Text
}


function Run(
  [string]$Label,
  [string]$Command
) {
  Log ""
  Log "==> $Label"
  Log $Command

  $stdout =
    Join-Path
      $work
      "stdout.txt"

  $stderr =
    Join-Path
      $work
      "stderr.txt"

  $process =
    Start-Process `
      -FilePath "cmd.exe" `
      -ArgumentList @(
        "/d",
        "/s",
        "/c",
        $Command
      ) `
      -WorkingDirectory $root `
      -NoNewWindow `
      -Wait `
      -PassThru `
      -RedirectStandardOutput $stdout `
      -RedirectStandardError $stderr

  foreach (
    $file in @(
      $stdout,
      $stderr
    )
  ) {
    if (
      Test-Path $file
    ) {
      $text =
        Get-Content `
          $file `
          -Raw `
          -ErrorAction SilentlyContinue

      if ($text) {
        Log $text.TrimEnd()
      }

      Remove-Item `
        $file `
        -Force `
        -ErrorAction SilentlyContinue
    }
  }

  if (
    $process.ExitCode -ne
      0
  ) {
    throw (
      "$Label failed with exit code " +
      "$($process.ExitCode)"
    )
  }

  Log "PASS: $Label"
}


function ZipLog {
  if (
    Test-Path $zip
  ) {
    Remove-Item `
      $zip `
      -Force `
      -ErrorAction SilentlyContinue
  }

  Compress-Archive `
    -Path (
      Join-Path
        $work
        "*"
    ) `
    -DestinationPath $zip `
    -Force
}


trap {
  Log ""
  Log "PHASE 008R3A.5B REPAIR V1: FAILED"
  Log ($_ | Out-String)
  Log $_.ScriptStackTrace

  ZipLog

  Write-Host ""
  Write-Host `
    "Diagnostic ZIP: $zip" `
    -ForegroundColor Yellow

  exit 1
}


Write-Host ""
Write-Host `
  "====================================================" `
  -ForegroundColor Cyan

Write-Host `
  "HIBEYA AKAL BUDI - PHASE 008R3A.5B REPAIR V1" `
  -ForegroundColor Cyan

Write-Host `
  "Resume Candidate Review After Successful Human Approval" `
  -ForegroundColor Cyan

Write-Host `
  "====================================================" `
  -ForegroundColor Cyan


$reviewDir =
  Join-Path
    $root
    "packages\assets\source\review\fruit"

$inspectorSource =
  Join-Path
    $root
    "phase008r3a5b-inspect-candidates.mjs"

$inspectorTarget =
  Join-Path
    $root
    "tools\assets\inspect-fruit-candidates.mjs"


foreach (
  $required in @(
    $reviewDir,
    $inspectorSource
  )
) {
  if (
    -not (
      Test-Path $required
    )
  ) {
    throw (
      "Required repair contract missing: " +
      $required
    )
  }
}


foreach (
  $id in @(
    "apple-red",
    "apple-green",
    "banana-yellow"
  )
) {
  $png =
    Join-Path
      $reviewDir
      "$id.png"

  $recordPath =
    Join-Path
      $reviewDir
      "$id.review.json"

  foreach (
    $required in @(
      $png,
      $recordPath
    )
  ) {
    if (
      -not (
        Test-Path $required
      )
    ) {
      throw (
        "Expected staged review file missing: " +
        $required
      )
    }
  }

  $record =
    Get-Content `
      $recordPath `
      -Raw |
    ConvertFrom-Json

  if (
    $record.visualReviewed -ne
      $true
  ) {
    throw (
      "$id: previous human visual approval " +
      "was not preserved"
    )
  }

  if (
    $record.productionEnabled -eq
      $true
  ) {
    throw (
      "$id: candidate was unexpectedly " +
      "production-enabled"
    )
  }

  Log (
    "PASS: $id prior human visual review " +
    "state verified"
  )
}


Copy-Item `
  $inspectorSource `
  $inspectorTarget `
  -Force

Log (
  "PASS: corrected technical candidate " +
  "inspector installed"
)

Log (
  "PASS: no re-staging or visual-review " +
  "flag rewrite was performed"
)


Run `
  "Verify project-local Sharp" `
  "node -e ""import('sharp').then(()=>console.log('sharp available')).catch(e=>{console.error(e);process.exit(1)})"""

Run `
  "Inspect staged fruit PNG candidates" `
  "node tools/assets/inspect-fruit-candidates.mjs"


# Runtime must still use the old fruit fallback until 008R3A.5C.
$runtimeFiles =
  @(
    "packages\assets\src\generated\commercialRegistry.generated.ts",
    "packages\assets\src\commercial.ts",
    "packages\assets\src\index.ts"
  )

$runtimeText =
  ""

foreach (
  $relative in $runtimeFiles
) {
  $full =
    Join-Path
      $root
      $relative

  if (
    Test-Path $full
  ) {
    $runtimeText +=
      (
        Get-Content
          $full
          -Raw
      ) +
      "`n"
  }
}


foreach (
  $id in @(
    "apple-red",
    "apple-green",
    "banana-yellow"
  )
) {
  if (
    $runtimeText -match
      [Regex]::Escape(
        "./$id.webp"
      )
  ) {
    throw (
      "$id WebP leaked into runtime before " +
      "controlled promotion"
    )
  }
}


Log (
  "PASS: reviewed fruit candidates remain " +
  "outside production runtime"
)


Run `
  "Assets typecheck" `
  "pnpm --filter @akal-budi/assets typecheck"

Run `
  "Storybook typecheck" `
  "pnpm --filter ui-storybook typecheck"

Run `
  "Learner typecheck" `
  "pnpm --filter learner-web typecheck"

Run `
  "Learner tests" `
  "pnpm --filter learner-web test"

Run `
  "Raster pipeline reproducibility" `
  "node tools/assets/build-raster-assets.mjs --check"

Run `
  "Frozen lockfile" `
  "pnpm install --frozen-lockfile"

Run `
  "Git whitespace" `
  "git diff --check"


Log ""
Log "PHASE 008R3A.5B REPAIR V1: PASS"
Log (
  "Human visual approvals remain recorded and " +
  "the staged PNG candidates pass technical inspection."
)
Log (
  "No fruit asset has been promoted to production."
)
Log (
  "Next: Phase 008R3A.5C controlled promotion."
)


ZipLog


Write-Host ""
Write-Host `
  "PHASE 008R3A.5B REPAIR V1: PASS" `
  -ForegroundColor Green

Write-Host `
  "Diagnostic ZIP: $zip" `
  -ForegroundColor Cyan
