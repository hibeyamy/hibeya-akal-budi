param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"

$previewPath = Join-Path $root "apps\ui-storybook\.storybook\preview.ts"
$learnerCss = Join-Path $root "apps\learner-web\src\index.css"
$learnerHome = Join-Path $root "apps\learner-web\src\shell\LearnerHome.tsx"
$storybookEnv = Join-Path $root "apps\ui-storybook\.env"
$journeyTest = Join-Path $root "tools\visual-regression\tests\learner-journey.spec.ts"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008f-repair-v5-$runId.log"

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
  if (-not (Test-Path $Path)) {
    return
  }

  $relative = $Path.Substring($root.Length).TrimStart("\")
  $safe = $relative.Replace("\","__")
  $destination = Join-Path $backups "$runId-$safe"

  Copy-Item $Path $destination -Force
}

function InvokeNative(
  [string]$Name,
  [string]$Command,
  [switch]$AllowFailure
) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`nCOMMAND: $Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008f-repair-v5-$stamp-out.log"
  $err = Join-Path $logs "phase008f-repair-v5-$stamp-err.log"

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

  if ($stdout) {
    Write-Host $stdout
    Add-Content $log $stdout -Encoding UTF8
  }

  if ($stderr) {
    Write-Host $stderr
    Add-Content $log $stderr -Encoding UTF8
  }

  $result = [PSCustomObject]@{
    ExitCode = $process.ExitCode
    Stdout = $stdout
    Stderr = $stderr
  }

  if ($process.ExitCode -eq 0) {
    Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
    Write-Host "PASS: $Name" -ForegroundColor Green
    return $result
  }

  if ($AllowFailure) {
    Write-Host "INFO: $Name did not pass; automatic fallback will be attempted." -ForegroundColor Yellow
    return $result
  }

  $diag = Join-Path $logs "FAILED-phase008f-repair-v5-$stamp-$($Name.Replace(' ','-')).log"

  WriteText `
    $diag `
    "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

  throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008F REPAIR V5: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  Write-Host "Manual intervention may be required only if the automatic fallback also failed." -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008F REPAIR V5" -ForegroundColor Cyan
Write-Host "Computed learner touch target styling" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# PRE-FLIGHT
# ------------------------------------------------------------------

foreach ($requiredPath in @(
  $previewPath,
  $learnerCss,
  $learnerHome,
  $storybookEnv,
  $journeyTest
)) {
  if (-not (Test-Path $requiredPath)) {
    throw "Required file missing: $requiredPath"
  }
}

$envText = Get-Content $storybookEnv -Raw

if ($envText -notmatch 'VITE_SUPABASE_URL=http://127\.0\.0\.1:54321') {
  throw "Storybook local Supabase environment from Repair V4 is missing."
}

$homeText = Get-Content $learnerHome -Raw

foreach ($buttonText in @(
  "Sambung belajar",
  "Lihat aktiviti"
)) {
  if ($homeText -notmatch [Regex]::Escape($buttonText)) {
    throw "LearnerHome contract drifted. Missing button: $buttonText"
  }
}

if ($homeText -notmatch 'min-h-14') {
  throw "LearnerHome no longer declares the intended 56px Tailwind minimum height."
}

Write-Host "PASS: Storybook environment from V4 is intact" -ForegroundColor Green
Write-Host "PASS: LearnerHome still declares min-h-14 touch targets" -ForegroundColor Green

Backup $previewPath
Backup $learnerHome

$previewBackup = Join-Path $backups "$runId-apps__ui-storybook__.storybook__preview.ts"
$homeBackup = Join-Path $backups "$runId-apps__learner-web__src__shell__LearnerHome.tsx"

# ------------------------------------------------------------------
# PRIMARY FIX
#
# Storybook currently imports design-system tokens + shared UI CSS,
# while learner-web production also imports its own index.css.
# Import the learner stylesheet into Storybook so computed utility styles
# match production instead of merely preserving className strings.
# ------------------------------------------------------------------

$previewText = Get-Content $previewPath -Raw
$learnerCssImport = 'import "../../../learner-web/src/index.css";'

if ($previewText -notmatch [Regex]::Escape($learnerCssImport)) {
  $anchor = 'import "@akal-budi/ui/styles.css";'

  if ($previewText -notmatch [Regex]::Escape($anchor)) {
    throw "Storybook preview CSS import anchor was not found."
  }

  $previewText = $previewText.Replace(
    $anchor,
    "$anchor`n$learnerCssImport"
  )

  WriteText $previewPath $previewText
  Write-Host "PASS: learner-web index.css added to Storybook preview" -ForegroundColor Green
}
else {
  Write-Host "PASS: learner-web index.css already imported by Storybook preview" -ForegroundColor Green
}

$buildResult = InvokeNative `
  "Storybook build with learner stylesheet" `
  "pnpm storybook:build" `
  -AllowFailure

$primaryPassed = $false

if ($buildResult.ExitCode -eq 0) {
  $touchResult = InvokeNative `
    "Touch-target focused regression" `
    'pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-journey.spec.ts -g "journey controls meet the preferred learner touch target"' `
    -AllowFailure

  if ($touchResult.ExitCode -eq 0) {
    $primaryPassed = $true
  }
}

# ------------------------------------------------------------------
# AUTOMATIC FALLBACK
#
# If Storybook cannot process learner index.css in its Vite pipeline, or if
# that stylesheet still does not produce the 56px computed target, restore
# preview.ts and make the accessibility invariant explicit at component level.
# This is intentionally limited to the two home controls validated by 008F.
# ------------------------------------------------------------------

if (-not $primaryPassed) {
  Write-Host ""
  Write-Host "Primary CSS-integration approach did not satisfy the computed-size gate." -ForegroundColor Yellow
  Write-Host "Applying automatic component-level accessibility fallback." -ForegroundColor Yellow

  if (Test-Path $previewBackup) {
    Copy-Item $previewBackup $previewPath -Force
    Write-Host "PASS: Storybook preview restored before fallback" -ForegroundColor Green
  }

  $homeSource = Get-Content $learnerHome -Raw

  $patchFile = Join-Path $env:TEMP "hibeya-phase008f-v5-home.cjs"

  WriteText $patchFile @'
const fs = require("fs");

const file = process.argv[2];
let source = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");

const labels = [
  "Sambung belajar",
  "Lihat aktiviti"
];

for (const label of labels) {
  const labelIndex = source.indexOf(`>${label}</button>`);

  if (labelIndex < 0) {
    throw new Error(`Button label not found: ${label}`);
  }

  const buttonStart = source.lastIndexOf("<button", labelIndex);

  if (buttonStart < 0) {
    throw new Error(`Opening button not found for: ${label}`);
  }

  const openEnd = source.indexOf(">", buttonStart);

  if (openEnd < 0 || openEnd > labelIndex) {
    throw new Error(`Opening button boundary invalid for: ${label}`);
  }

  const opening = source.slice(buttonStart, openEnd + 1);

  if (opening.includes("style={{")) {
    if (!opening.includes("minHeight")) {
      throw new Error(
        `Existing style prop without minHeight found for ${label}; refusing unsafe merge`
      );
    }

    continue;
  }

  const patchedOpening = opening.replace(
    /\n(\s*)>/,
    `\n$1  style={{\n$1    minHeight: "56px"\n$1  }}\n$1>`
  );

  if (patchedOpening === opening) {
    throw new Error(`Could not insert minHeight style for: ${label}`);
  }

  source =
    source.slice(0, buttonStart) +
    patchedOpening +
    source.slice(openEnd + 1);
}

fs.writeFileSync(file, source, "utf8");
console.log("PASS: explicit 56px minimum height applied to LearnerHome controls");
'@

  & node $patchFile $learnerHome

  if ($LASTEXITCODE -ne 0) {
    if (Test-Path $homeBackup) {
      Copy-Item $homeBackup $learnerHome -Force
    }

    throw "Automatic LearnerHome fallback patch failed."
  }

  Remove-Item $patchFile -Force -ErrorAction SilentlyContinue

  InvokeNative "Learner web typecheck after fallback" "pnpm --filter learner-web typecheck" | Out-Null
  InvokeNative "Storybook build after fallback" "pnpm storybook:build" | Out-Null

  InvokeNative `
    "Touch-target focused regression after fallback" `
    'pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-journey.spec.ts -g "journey controls meet the preferred learner touch target"' |
    Out-Null

  Write-Host "PASS: automatic component-level fallback satisfies computed touch target" -ForegroundColor Green
}
else {
  Write-Host "PASS: Storybook now uses learner production stylesheet for computed touch targets" -ForegroundColor Green
}

# ------------------------------------------------------------------
# FULL VALIDATION
# ------------------------------------------------------------------

InvokeNative "Learner journey end-to-end regression" "pnpm qa:journey" | Out-Null
InvokeNative "Storybook typecheck" "pnpm --filter ui-storybook typecheck" | Out-Null
InvokeNative "Learner web typecheck" "pnpm --filter learner-web typecheck" | Out-Null
InvokeNative "Learner web tests" "pnpm --filter learner-web test" | Out-Null
InvokeNative "Repository typecheck" "pnpm typecheck" | Out-Null
InvokeNative "All tests" "pnpm test" | Out-Null
InvokeNative "Production build" "pnpm build" | Out-Null
InvokeNative "Accessibility regression" "pnpm qa:a11y" | Out-Null
InvokeNative "Visual regression" "pnpm qa:visual" | Out-Null
InvokeNative "Git whitespace check" "git diff --check" | Out-Null

if ($Commit) {
  InvokeNative `
    "Stage Phase 008F Repair V5" `
    "git add apps/ui-storybook/.storybook/preview.ts apps/learner-web/src/shell/LearnerHome.tsx apps/ui-storybook/.env tools/visual-regression/tests/learner-journey.spec.ts package.json" |
    Out-Null

  InvokeNative `
    "Commit Phase 008F Repair V5" `
    'git commit -m "fix: enforce computed learner touch targets"' |
    Out-Null
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008F REPAIR V5: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No manual intervention was required." -ForegroundColor Cyan
