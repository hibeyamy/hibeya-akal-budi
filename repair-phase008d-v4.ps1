param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$tsconfig = Join-Path $root "apps\ui-storybook\tsconfig.json"
$envDecl = Join-Path $root "apps\ui-storybook\vite-env.d.ts"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008d-repair-v4-$runId.log"

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

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase008d-repair-v4-$stamp-out.log"
  $err = Join-Path $logs "phase008d-repair-v4-$stamp-err.log"

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

  if ($process.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase008d-repair-v4-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($process.ExitCode)`n`nSTDOUT:`n$stdout`n`nSTDERR:`n$stderr"

    throw "$Name failed with exit code $($process.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content `
    $log `
    "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" `
    -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 008D REPAIR V4: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008D REPAIR V4" -ForegroundColor Cyan
Write-Host "Include Storybook ImportMeta declaration in TS program" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $tsconfig)) {
  throw "Missing Storybook tsconfig: $tsconfig"
}

if (-not (Test-Path $envDecl)) {
  throw "Missing Storybook ImportMeta declaration: $envDecl"
}

Backup $tsconfig
Backup $envDecl

$temp = Join-Path $env:TEMP "hibeya-phase008d-repair-v4-tsconfig.cjs"

WriteText $temp @'
const fs = require("fs");

const file = process.argv[2];

const config =
  JSON.parse(
    fs.readFileSync(
      file,
      "utf8"
    )
  );

const include =
  Array.isArray(config.include)
    ? config.include
    : [];

config.include =
  Array.from(
    new Set([
      ...include,
      "vite-env.d.ts"
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
  "PASS: vite-env.d.ts added to Storybook tsconfig include"
);
'@

& node $temp $tsconfig

if ($LASTEXITCODE -ne 0) {
  throw "Could not patch Storybook tsconfig include."
}

Remove-Item $temp -Force -ErrorAction SilentlyContinue

# Confirm configuration without producing the enormous --listFiles output.
Run `
  "Show Storybook TypeScript config" `
  "pnpm --filter ui-storybook exec tsc --showConfig"

Run `
  "Storybook typecheck" `
  "pnpm --filter ui-storybook typecheck"

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
    "Stage Phase 008D repair V4" `
    "git add apps/ui-storybook/tsconfig.json apps/ui-storybook/vite-env.d.ts apps/learner-web/src/features/play/ActivityPlayer.tsx apps/learner-web/src/journey/LearnerActivityBridge.tsx"

  Run `
    "Commit Phase 008D repair V4" `
    'git commit -m "fix: include storybook import meta declaration"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008D REPAIR V4: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Storybook now explicitly includes vite-env.d.ts in its TypeScript program." -ForegroundColor Cyan
