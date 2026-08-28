param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$journeyRoot = Join-Path $root "apps\learner-web\src\journey"
$storyPath = Join-Path $root "apps\ui-storybook\stories\LearnerJourney.stories.tsx"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008c-repair-v2-$runId.log"

function WriteText([string]$Path,[string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  [IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [Text.UTF8Encoding]::new($false)
  )
}

function Backup([string]$Path) {
  if (-not (Test-Path $Path)) { return }

  $relative = $Path.Substring($root.Length).TrimStart("\")
  $safe = $relative.Replace("\","__")

  Copy-Item $Path (Join-Path $backups "$runId-$safe") -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008c-repair-v2-$stamp-out.log"
  $err = Join-Path $logs "phase008c-repair-v2-$stamp-err.log"

  $process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $stdout = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $stderr = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($stdout) { Write-Host $stdout; Add-Content $log $stdout -Encoding UTF8 }
  if ($stderr) { Write-Host $stderr; Add-Content $log $stderr -Encoding UTF8 }

  if ($process.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase008c-repair-v2-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008C REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008C REPAIR V2" -ForegroundColor Cyan
Write-Host "Resolve LearnerJourney basename collision" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$legacyTs = Join-Path $journeyRoot "LearnerJourney.ts"
$componentTsx = Join-Path $journeyRoot "LearnerJourney.tsx"
$screenTsx = Join-Path $journeyRoot "LearnerJourneyScreen.tsx"
$indexPath = Join-Path $journeyRoot "index.ts"

if (-not (Test-Path $componentTsx)) {
  throw "Expected component file missing: $componentTsx"
}

if (-not (Test-Path $indexPath)) {
  throw "Journey index missing: $indexPath"
}

Write-Host ""
Write-Host "Detected journey files:" -ForegroundColor Cyan
Get-ChildItem $journeyRoot -File |
  Select-Object Name |
  Format-Table -AutoSize

if (Test-Path $legacyTs) {
  Write-Host "INFO: LearnerJourney.ts exists and can shadow LearnerJourney.tsx during bundling." -ForegroundColor Yellow
}
else {
  Write-Host "INFO: No LearnerJourney.ts file is present, but we will still remove the ambiguous basename." -ForegroundColor Yellow
}

Backup $componentTsx
Backup $indexPath
Backup $storyPath

# Create an unambiguous component filename.
$componentSource = Get-Content $componentTsx -Raw

$componentSource =
  $componentSource.Replace(
    "export function LearnerJourney()",
    "export function LearnerJourneyScreen()"
  )

WriteText $screenTsx $componentSource

# Preserve any legacy LearnerJourney.ts file. Remove only the Phase 008C .tsx
# after creating the uniquely named component.
Remove-Item $componentTsx -Force

# Rebuild the barrel explicitly so component and state-model names cannot collide.
$indexSource = @'
export {
  LearnerJourneyScreen
} from "./LearnerJourneyScreen";

export {
  LearnerExplore,
  type LearnerExploreProps
} from "./LearnerExplore";

export {
  LearnerActivityBridge,
  type LearnerActivityBridgeProps
} from "./LearnerActivityBridge";

export {
  initialLearnerJourneyState,
  learnerJourneyReducer,
  type LearnerJourneyAction,
  type LearnerJourneyState,
  type LearnerJourneyView
} from "./learnerJourney";

export {
  useLearnerJourney
} from "./useLearnerJourney";
'@

WriteText $indexPath $indexSource

$storySource = @'
import {
  LearnerJourneyScreen
} from "../../learner-web/src/journey";

export default {
  title:
    "Learner/Journey"
};

export function Default() {
  return (
    <LearnerJourneyScreen />
  );
}
'@

WriteText $storyPath $storySource

Write-Host "PASS: ambiguous LearnerJourney component basename removed" -ForegroundColor Green
Write-Host "PASS: Storybook now imports LearnerJourneyScreen explicitly" -ForegroundColor Green

Run "Learner web typecheck" "pnpm --filter learner-web typecheck"
Run "Learner web tests" "pnpm --filter learner-web test"
Run "Storybook production build" "pnpm storybook:build"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression verification" "pnpm qa:visual"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 008C repair" "git add apps/learner-web/src/journey apps/ui-storybook/stories/LearnerJourney.stories.tsx"
  Run "Commit Phase 008C repair" 'git commit -m "fix: resolve learner journey module collision"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008C REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
