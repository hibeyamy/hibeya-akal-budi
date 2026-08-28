param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$envDecl = Join-Path $root "apps\ui-storybook\vite-env.d.ts"
$tsconfig = Join-Path $root "apps\ui-storybook\tsconfig.json"
$supabaseSource = Join-Path $root "apps\learner-web\src\lib\supabase.ts"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase008d-repair-v5-$runId.log"

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
  $out = Join-Path $logs "phase008d-repair-v5-$stamp-out.log"
  $err = Join-Path $logs "phase008d-repair-v5-$stamp-err.log"

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
    $diag = Join-Path $logs "FAILED-phase008d-repair-v5-$stamp-$($Name.Replace(' ','-')).log"

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
  Write-Host "PHASE 008D REPAIR V5: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 008D REPAIR V5" -ForegroundColor Cyan
Write-Host "Correct Storybook Vite env value typing" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if (-not (Test-Path $envDecl)) {
  throw "Missing Storybook vite-env.d.ts: $envDecl"
}

if (-not (Test-Path $tsconfig)) {
  throw "Missing Storybook tsconfig.json: $tsconfig"
}

if (-not (Test-Path $supabaseSource)) {
  throw "Missing learner Supabase source: $supabaseSource"
}

Backup $envDecl
Backup $tsconfig

Write-Host ""
Write-Host "==> Reviewing imported learner Supabase source" -ForegroundColor Cyan

Get-Content $supabaseSource |
  Select-Object -First 60 |
  ForEach-Object {
    Write-Host $_
    Add-Content $log $_ -Encoding UTF8
  }

# The previous declaration used:
#   [key: string]: string | boolean | undefined
#
# That made VITE_* values boolean-capable. In the guarded createClient branch
# TypeScript correctly narrowed that union to string | true, hence TS2345.
#
# Vite user-defined VITE_* environment variables are strings at runtime
# (or absent), while Vite built-ins such as DEV/PROD/SSR are booleans.
# Model those categories separately instead of mixing them into one index type.

WriteText $envDecl @'
interface ImportMetaEnv {
  readonly BASE_URL:
    string;

  readonly MODE:
    string;

  readonly DEV:
    boolean;

  readonly PROD:
    boolean;

  readonly SSR:
    boolean;

  readonly VITE_SUPABASE_URL?:
    string;

  readonly VITE_SUPABASE_ANON_KEY?:
    string;

  readonly [key: `VITE_${string}`]:
    string |
    undefined;
}

interface ImportMeta {
  readonly env:
    ImportMetaEnv;
}
'@

Write-Host ""
Write-Host "PASS: VITE_* variables are now string-only; Vite boolean built-ins remain explicitly boolean." -ForegroundColor Green

# Confirm that V4's include repair is still present.
$temp = Join-Path $env:TEMP "hibeya-phase008d-repair-v5-check.cjs"

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

if (
  !Array.isArray(config.include) ||
  !config.include.includes("vite-env.d.ts")
) {
  console.error(
    "vite-env.d.ts is not included by Storybook tsconfig"
  );

  process.exit(1);
}

console.log(
  "PASS: Storybook tsconfig still includes vite-env.d.ts"
);
'@

& node $temp $tsconfig

if ($LASTEXITCODE -ne 0) {
  throw "Storybook tsconfig no longer includes vite-env.d.ts."
}

Remove-Item $temp -Force -ErrorAction SilentlyContinue

Run `
  "Storybook typecheck" `
  "pnpm --filter ui-storybook typecheck"

Run `
  "Learner web typecheck" `
  "pnpm --filter learner-web typecheck"

Run `
  "Learner web tests" `
  "pnpm --filter learner-web test"

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
  "Git whitespace check" `
  "git diff --check"

if ($Commit) {
  Run `
    "Stage Phase 008D Repair V5" `
    "git add apps/ui-storybook/vite-env.d.ts apps/ui-storybook/tsconfig.json apps/learner-web/src/features/play/ActivityPlayer.tsx apps/learner-web/src/journey/LearnerActivityBridge.tsx"

  Run `
    "Commit Phase 008D Repair V5" `
    'git commit -m "fix: correct storybook vite environment typing"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 008D REPAIR V5: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "VITE_* env values remain string-typed." -ForegroundColor Cyan
Write-Host "DEV/PROD/SSR remain boolean-typed." -ForegroundColor Cyan
Write-Host "No Supabase application code was modified." -ForegroundColor Cyan
