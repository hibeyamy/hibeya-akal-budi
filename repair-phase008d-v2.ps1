param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$tsconfig = Join-Path $root "apps\ui-storybook\tsconfig.json"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008d-repair-v2-$runId.log"

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
      "phase008d-repair-v2-$stamp-out.log"

  $err =
    Join-Path `
      $logs `
      "phase008d-repair-v2-$stamp-err.log"

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

  if ($process.ExitCode -ne 0) {
    $diag =
      Join-Path `
        $logs `
        "FAILED-phase008d-repair-v2-$stamp-$($Name.Replace(' ','-')).log"

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
  Write-Host "PHASE 008D REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008D REPAIR V2" -ForegroundColor Cyan
Write-Host "Storybook Vite ImportMeta typing" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $tsconfig)) {
  throw "Missing Storybook tsconfig: $tsconfig"
}

$backup =
  Join-Path `
    $backups `
    "$runId-apps__ui-storybook__tsconfig.json"

Copy-Item $tsconfig $backup -Force

Write-Host "Backup: $backup"

# Patch JSON using Node so comments/PowerShell nested-property issues do not apply.
$temp =
  Join-Path `
    $env:TEMP `
    "hibeya-phase008d-repair-v2-tsconfig.cjs"

$patch = @'
const fs = require("fs");

const file = process.argv[2];

const config =
  JSON.parse(
    fs.readFileSync(
      file,
      "utf8"
    )
  );

config.compilerOptions ??= {};

const existing =
  Array.isArray(
    config.compilerOptions.types
  )
    ? config.compilerOptions.types
    : [];

config.compilerOptions.types =
  Array.from(
    new Set([
      ...existing,
      "vite/client"
    ])
  );

fs.writeFileSync(
  file,
  JSON.stringify(
    config,
    null,
    2
  ) + "\n",
  "utf8"
);

console.log(
  "PASS: apps/ui-storybook/tsconfig.json includes vite/client"
);
'@

WriteText $temp $patch

& node $temp $tsconfig

if ($LASTEXITCODE -ne 0) {
  throw "Could not patch Storybook tsconfig."
}

Remove-Item `
  $temp `
  -Force `
  -ErrorAction SilentlyContinue

# Fast targeted confirmation first.
Run `
  "Storybook typecheck" `
  "pnpm --filter ui-storybook typecheck"

# Then resume the full 008D validation chain from the point that failed.
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
  "Storybook build" `
  "pnpm storybook:build"

Run `
  "Accessibility regression" `
  "pnpm qa:a11y"

Run `
  "Visual regression" `
  "pnpm qa:visual"

Run `
  "Git whitespace check" `
  "git diff --check"

if ($Commit) {
  Run `
    "Stage Phase 008D repair" `
    "git add apps/ui-storybook/tsconfig.json apps/learner-web/src/features/play/ActivityPlayer.tsx apps/learner-web/src/journey/LearnerActivityBridge.tsx"

  Run `
    "Commit Phase 008D repair" `
    'git commit -m "fix: align storybook vite typings for learner runtime"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008D REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The ActivityPlayer adapter was not rolled back." -ForegroundColor Cyan
Write-Host "Storybook now understands Vite's import.meta.env typing when compiling learner-web source." -ForegroundColor Cyan
