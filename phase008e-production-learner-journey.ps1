param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

$appPath = Join-Path $root "apps\learner-web\src\App.tsx"
$journeyPath = Join-Path $root "apps\learner-web\src\journey\LearnerJourneyScreen.tsx"
$playerPath = Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008e-$runId.log"

function WriteText([string]$Path,[string]$Content) {
  $dir = Split-Path -Parent $Path

  if (
    $dir -and
    -not (Test-Path $dir)
  ) {
    New-Item `
      -ItemType Directory `
      -Force `
      -Path $dir |
      Out-Null
  }

  [IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [Text.UTF8Encoding]::new($false)
  )
}

function Backup([string]$Path) {
  if (-not (Test-Path $Path)) {
    return
  }

  $relative =
    $Path.Substring(
      $root.Length
    ).TrimStart("\")

  $safe =
    $relative.Replace(
      "\",
      "__"
    )

  Copy-Item `
    $Path `
    (Join-Path $backups "$runId-$safe") `
    -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan

  Add-Content `
    $log `
    "`n==> $Name`nCOMMAND: $Command" `
    -Encoding UTF8

  $stamp =
    Get-Date `
      -Format "yyyyMMdd-HHmmssfff"

  $out =
    Join-Path `
      $logs `
      "phase008e-$stamp-out.log"

  $err =
    Join-Path `
      $logs `
      "phase008e-$stamp-err.log"

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
      -RedirectStandardOutput $out `
      -RedirectStandardError $err `
      -NoNewWindow `
      -Wait `
      -PassThru

  $stdout =
    if (Test-Path $out) {
      Get-Content $out -Raw
    }
    else {
      ""
    }

  $stderr =
    if (Test-Path $err) {
      Get-Content $err -Raw
    }
    else {
      ""
    }

  if ($stdout) {
    Write-Host $stdout
    Add-Content $log $stdout -Encoding UTF8
  }

  if ($stderr) {
    Write-Host $stderr
    Add-Content $log $stderr -Encoding UTF8
  }

  if (
    $process.ExitCode -ne 0
  ) {
    $diag =
      Join-Path `
        $logs `
        "FAILED-phase008e-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
  }

  Remove-Item `
    $out,$err `
    -Force `
    -ErrorAction SilentlyContinue

  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content `
    $log `
    "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
    -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008E: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008E" -ForegroundColor Cyan
Write-Host "Production Learner Journey Activation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $appPath)) {
  throw "Missing learner App.tsx: $appPath"
}

if (-not (Test-Path $journeyPath)) {
  throw "Missing LearnerJourneyScreen.tsx: $journeyPath"
}

if (-not (Test-Path $playerPath)) {
  throw "Missing ActivityPlayer.tsx: $playerPath"
}

Backup $appPath

# ------------------------------------------------------------------
# Structural patch.
#
# The inspected App contract is:
#   - checking -> loading screen
#   - inactive -> DeviceActivation
#   - active -> <ActivityPlayer />
#
# This phase changes ONLY the active learner destination.
# Device activation, offline-first identity validation and activation state
# remain untouched.
# ------------------------------------------------------------------

$temp =
  Join-Path `
    $env:TEMP `
    "hibeya-phase008e-patch.cjs"

WriteText $temp @'
const fs = require("fs");

const file = process.argv[2];

let source =
  fs.readFileSync(
    file,
    "utf8"
  ).replace(/\r\n/g,"\n");

const oldImport =
`import {
  ActivityPlayer
} from "./features/play/ActivityPlayer";
`;

const newImport =
`import {
  LearnerJourneyScreen
} from "./journey";
`;

const oldReturn =
`  return (
    <ActivityPlayer />
  );
`;

const newReturn =
`  return (
    <LearnerJourneyScreen />
  );
`;

if (
  source.includes(
    newImport
  ) &&
  source.includes(
    newReturn
  )
) {
  console.log(
    "PASS: production learner journey already activated"
  );

  process.exit(0);
}

if (
  !source.includes(
    oldImport
  )
) {
  throw new Error(
    "Expected ActivityPlayer import was not found. App.tsx has drifted; refusing blind patch."
  );
}

if (
  !source.includes(
    oldReturn
  )
) {
  throw new Error(
    "Expected active <ActivityPlayer /> return was not found. App.tsx has drifted; refusing blind patch."
  );
}

source =
  source.replace(
    oldImport,
    newImport
  );

source =
  source.replace(
    oldReturn,
    newReturn
  );

fs.writeFileSync(
  file,
  source,
  "utf8"
);

console.log(
  "PASS: active learner route changed from ActivityPlayer to LearnerJourneyScreen"
);
'@

& node $temp $appPath

if ($LASTEXITCODE -ne 0) {
  throw "App.tsx structural integration failed."
}

Remove-Item `
  $temp `
  -Force `
  -ErrorAction SilentlyContinue

# ------------------------------------------------------------------
# Post-patch contract guards.
# ------------------------------------------------------------------

$appSource =
  Get-Content `
    $appPath `
    -Raw

if (
  $appSource -notmatch
  'LearnerJourneyScreen'
) {
  throw "LearnerJourneyScreen is not active in App.tsx."
}

if (
  $appSource -match
  '<ActivityPlayer\s*/>'
) {
  throw "Legacy direct ActivityPlayer runtime is still active in App.tsx."
}

foreach (
  $required
  in @(
    "validateStoredDevice",
    "DeviceActivation",
    "clearLearnerDevice",
    "getLearnerDevice",
    'activationState ===',
    '"checking"',
    '"inactive"',
    '"active"'
  )
) {
  if (
    $appSource -notmatch
    [Regex]::Escape(
      $required
    )
  ) {
    throw "Activation contract guard failed. Missing: $required"
  }
}

$playerSource =
  Get-Content `
    $playerPath `
    -Raw

if (
  $playerSource -notmatch
  'export function ActivityPlayerAdapter'
) {
  throw "Phase 008D explicit ActivityPlayerAdapter is missing."
}

if (
  $playerSource -notmatch
  'export function ActivityPlayer\(\)'
) {
  throw "Legacy automatic ActivityPlayer export was unexpectedly removed."
}

Write-Host ""
Write-Host "PASS: activation flow preserved" -ForegroundColor Green
Write-Host "PASS: production active state now enters LearnerJourneyScreen" -ForegroundColor Green
Write-Host "PASS: explicit ActivityPlayer adapter remains available to journey" -ForegroundColor Green
Write-Host "PASS: legacy automatic ActivityPlayer remains preserved for compatibility" -ForegroundColor Green

# ------------------------------------------------------------------
# QA.
# ------------------------------------------------------------------

Run `
  "Learner web typecheck" `
  "pnpm --filter learner-web typecheck"

Run `
  "Learner web tests" `
  "pnpm --filter learner-web test"

Run `
  "Learner production build" `
  "pnpm --filter learner-web build"

Run `
  "Storybook typecheck" `
  "pnpm --filter ui-storybook typecheck"

Run `
  "Storybook build" `
  "pnpm storybook:build"

Run `
  "Repository typecheck" `
  "pnpm typecheck"

Run `
  "All tests" `
  "pnpm test"

Run `
  "Production build" `
  "pnpm build"

Run `
  "Accessibility regression" `
  "pnpm qa:a11y"

Run `
  "Visual regression" `
  "pnpm qa:visual"

Run `
  "Content compiler check" `
  "pnpm content:check"

Run `
  "Curriculum validation" `
  "pnpm curriculum:validate"

Run `
  "Git whitespace check" `
  "git diff --check"

if ($Commit) {
  Run `
    "Stage Phase 008E" `
    "git add apps/learner-web/src/App.tsx"

  Run `
    "Commit Phase 008E" `
    'git commit -m "feat: activate learner journey in production runtime"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008E: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Production flow is now:" -ForegroundColor Cyan
Write-Host "  device validation -> learner journey -> explicit activity adapter -> ActivityPlayer runtime" -ForegroundColor White
