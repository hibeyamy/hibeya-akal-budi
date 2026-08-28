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
$log = Join-Path $logs "phase008f-repair-v6-$runId.log"

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
  if (-not (Test-Path $Path)) { return $null }

  $relative = $Path.Substring($root.Length).TrimStart("\")
  $safe = $relative.Replace("\","__")
  $destination = Join-Path $backups "$runId-$safe"

  Copy-Item $Path $destination -Force
  return $destination
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
  $out = Join-Path $logs "phase008f-repair-v6-$stamp-out.log"
  $err = Join-Path $logs "phase008f-repair-v6-$stamp-err.log"

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
    Write-Host "INFO: $Name failed; guarded fallback path will be evaluated." -ForegroundColor Yellow
    return $result
  }

  $diag = Join-Path $logs "FAILED-phase008f-repair-v6-$stamp-$($Name.Replace(' ','-')).log"
  WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

  throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008F REPAIR V6: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  Write-Host "If the script reports MANUAL ACTION REQUIRED, follow that exact instruction only." -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008F REPAIR V6" -ForegroundColor Cyan
Write-Host "Verified Storybook CSS path + robust touch-target fallback" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# PRE-FLIGHT Ã¢â‚¬â€ verify all paths and current source before editing.
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

foreach ($buttonText in @("Sambung belajar","Lihat aktiviti")) {
  if ($homeText -notmatch [Regex]::Escape($buttonText)) {
    throw "LearnerHome contract drifted. Missing button: $buttonText"
  }
}

if ($homeText -notmatch 'min-h-14') {
  throw "LearnerHome no longer declares the intended 56px minimum-height utility."
}

# Compute and VERIFY the CSS path relative to preview.ts before writing it.
$previewDir = Split-Path -Parent $previewPath
$resolvedLearnerCss = (Resolve-Path $learnerCss).Path

# Windows PowerShell 5.1-safe relative-path calculation.
# Avoid Path.GetRelativePath (.NET Core API) and avoid line-leading method calls.
$previewBasePath = (Resolve-Path $previewDir).Path.TrimEnd("\") + "\"
$previewBaseUri = New-Object System.Uri($previewBasePath)
$learnerCssUri = New-Object System.Uri($resolvedLearnerCss)
$relativeUri = $previewBaseUri.MakeRelativeUri($learnerCssUri)
$relativeCss = [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace("\","/")
if ($relativeCss -ne "../../learner-web/src/index.css") {
  throw "Unexpected Storybook -> learner CSS relative path: $relativeCss"
}

Write-Host "PASS: verified learner CSS relative path = $relativeCss" -ForegroundColor Green
Write-Host "PASS: LearnerHome source contract verified" -ForegroundColor Green
Write-Host "PASS: Storybook local Supabase environment verified" -ForegroundColor Green

$previewBackup = Backup $previewPath
$homeBackup = Backup $learnerHome

# ------------------------------------------------------------------
# PRIMARY FIX Ã¢â‚¬â€ import the exact production learner stylesheet using
# the path verified above.
# ------------------------------------------------------------------

$previewText = Get-Content $previewPath -Raw

# Remove any stale bad import left from interrupted prior attempts.
$previewText = [Regex]::Replace(
  $previewText,
  '(?m)^\s*import\s+["'']\.\./\.\./\.\./learner-web/src/index\.css["''];?\s*\r?\n?',
  ''
)

$correctImport = "import `"$relativeCss`";"

if ($previewText -notmatch [Regex]::Escape($correctImport)) {
  $anchor = 'import "@akal-budi/ui/styles.css";'

  if ($previewText -notmatch [Regex]::Escape($anchor)) {
    throw "Storybook preview CSS import anchor was not found."
  }

  $previewText = $previewText.Replace(
    $anchor,
    "$anchor`n$correctImport"
  )
}

WriteText $previewPath $previewText

# Confirm import target resolves before invoking Storybook.
$importTarget = Join-Path $previewDir $relativeCss

if (-not (Test-Path $importTarget)) {
  if ($previewBackup) {
    Copy-Item $previewBackup $previewPath -Force
  }

  throw "Generated Storybook CSS import does not resolve on disk: $importTarget"
}

Write-Host "PASS: Storybook preview now imports verified learner stylesheet path" -ForegroundColor Green

$primaryBuild = InvokeNative `
  "Storybook build with verified learner stylesheet" `
  "pnpm storybook:build" `
  -AllowFailure

$primaryPassed = $false

if ($primaryBuild.ExitCode -eq 0) {
  $primaryTouch = InvokeNative `
    "Focused computed touch-target regression" `
    'pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-journey.spec.ts -g "journey controls meet the preferred learner touch target"' `
    -AllowFailure

  if ($primaryTouch.ExitCode -eq 0) {
    $primaryPassed = $true
  }
}

# ------------------------------------------------------------------
# GUARDED FALLBACK Ã¢â‚¬â€ only if production stylesheet integration still
# cannot satisfy the computed 56px browser invariant.
#
# Unlike V5, this parser does NOT expect button text and closing tags
# on the same line. It finds complete <button>...</button> blocks and
# matches normalised text content.
# ------------------------------------------------------------------

if (-not $primaryPassed) {
  Write-Host ""
  Write-Host "Primary stylesheet path did not satisfy the focused gate." -ForegroundColor Yellow
  Write-Host "Applying robust component-level fallback." -ForegroundColor Yellow

  if ($previewBackup) {
    Copy-Item $previewBackup $previewPath -Force
    Write-Host "PASS: Storybook preview restored before fallback" -ForegroundColor Green
  }

  $patchFile = Join-Path $env:TEMP "hibeya-phase008f-v6-home.cjs"

  WriteText $patchFile @'
const fs = require("fs");

const file = process.argv[2];
let source = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");

const labels = [
  "Sambung belajar",
  "Lihat aktiviti"
];

function normaliseText(value) {
  return value
    .replace(/<[^>]+>/g, " ")
    .replace(/\{[\s\S]*?\}/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

for (const label of labels) {
  const buttonRegex = /<button\b[\s\S]*?<\/button>/g;
  const matches = [...source.matchAll(buttonRegex)];

  const match = matches.find(item =>
    normaliseText(item[0]).includes(label)
  );

  if (!match || match.index == null) {
    throw new Error(
      `Could not locate complete button block for: ${label}`
    );
  }

  const block = match[0];
  const openTagMatch = block.match(/^<button\b[\s\S]*?>/);

  if (!openTagMatch) {
    throw new Error(
      `Could not locate opening button tag for: ${label}`
    );
  }

  let openTag = openTagMatch[0];

  if (/minHeight\s*:/.test(openTag)) {
    continue;
  }

  if (/\sstyle\s*=\s*\{\{/.test(openTag)) {
    throw new Error(
      `Existing style object requires manual-safe merge for: ${label}`
    );
  }

  const closing = openTag.lastIndexOf(">");

  if (closing < 0) {
    throw new Error(
      `Malformed opening tag for: ${label}`
    );
  }

  const patchedOpenTag =
    openTag.slice(0, closing) +
    '\n          style={{ minHeight: "56px" }}' +
    openTag.slice(closing);

  const patchedBlock =
    patchedOpenTag +
    block.slice(openTag.length);

  source =
    source.slice(0, match.index) +
    patchedBlock +
    source.slice(match.index + block.length);
}

for (const label of labels) {
  const blocks = [...source.matchAll(/<button\b[\s\S]*?<\/button>/g)];

  const block = blocks.find(item =>
    normaliseText(item[0]).includes(label)
  )?.[0];

  if (!block || !/minHeight\s*:\s*"56px"/.test(block)) {
    throw new Error(
      `Postcondition failed for: ${label}`
    );
  }
}

fs.writeFileSync(file, source, "utf8");
console.log(
  "PASS: explicit 56px minimum height applied to both LearnerHome controls"
);
'@

  & node $patchFile $learnerHome
  $patchExit = $LASTEXITCODE

  Remove-Item $patchFile -Force -ErrorAction SilentlyContinue

  if ($patchExit -ne 0) {
    if ($homeBackup) {
      Copy-Item $homeBackup $learnerHome -Force
    }

    Write-Host ""
    Write-Host "MANUAL ACTION REQUIRED:" -ForegroundColor Red
    Write-Host "Do not edit anything yet. Send the new phase008f-repair-v6 log to me." -ForegroundColor Yellow
    throw "Robust LearnerHome fallback could not be applied safely."
  }

  InvokeNative `
    "Learner typecheck after fallback" `
    "pnpm --filter learner-web typecheck" |
    Out-Null

  InvokeNative `
    "Storybook build after fallback" `
    "pnpm storybook:build" |
    Out-Null

  InvokeNative `
    "Focused touch-target regression after fallback" `
    'pnpm exec playwright test -c tools/visual-regression/playwright.config.ts tools/visual-regression/tests/learner-journey.spec.ts -g "journey controls meet the preferred learner touch target"' |
    Out-Null

  Write-Host "PASS: robust fallback satisfies computed 56px touch target" -ForegroundColor Green
}
else {
  Write-Host "PASS: verified production learner stylesheet satisfies computed 56px touch target" -ForegroundColor Green
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
    "Stage Phase 008F Repair V6" `
    "git add apps/ui-storybook/.storybook/preview.ts apps/learner-web/src/shell/LearnerHome.tsx apps/ui-storybook/.env tools/visual-regression/tests/learner-journey.spec.ts package.json" |
    Out-Null

  InvokeNative `
    "Commit Phase 008F Repair V6" `
    'git commit -m "fix: align learner touch targets across storybook and runtime"' |
    Out-Null
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008F REPAIR V6: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No manual intervention required." -ForegroundColor Cyan
