param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$playerPath = Join-Path $root "apps\learner-web\src\features\play\ActivityPlayer.tsx"
$phasePath = Join-Path $root "phase007d-first-original-asset-batch.ps1"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007d-repair-v3-$runId.log"

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

function Log([string]$Message) {
  Write-Host $Message
  Add-Content -Path $log -Value $Message -Encoding UTF8
}

trap {
  WriteText $log @"
PHASE 007D REPAIR V3 FAILED

TIME:
$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")

MESSAGE:
$($_.Exception.Message)

ERROR:
$($_ | Out-String)

POSITION:
$($_.InvocationInfo.PositionMessage)

STACK:
$($_.ScriptStackTrace)
"@

  Write-Host ""
  Write-Host "PHASE 007D REPAIR V3: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007D REPAIR V3" -ForegroundColor Cyan
Write-Host "Structural ActivityPlayer asset-render reconciliation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $playerPath)) {
  throw "ActivityPlayer not found: $playerPath"
}

if (-not (Test-Path $phasePath)) {
  throw "Phase 007D installer not found: $phasePath"
}

$backup = Join-Path $backups "$runId-apps__learner-web__src__features__play__ActivityPlayer.tsx"
Copy-Item $playerPath $backup -Force
Log "Backup: $backup"

# ------------------------------------------------------------------
# Patch only the JSX element that directly renders {asset.value}.
# We do not depend on formatting, line breaks, attribute order or
# Tailwind class names.
# ------------------------------------------------------------------

$tempPatch = Join-Path $env:TEMP "hibeya-phase007d-repair-player.cjs"

$patchSource = @'
const fs = require("fs");

const file = process.argv[2];

let source =
  fs.readFileSync(
    file,
    "utf8"
  ).replace(/\r\n/g, "\n");

if (
  source.includes(
    'asset.type === "image"'
  )
) {
  console.log(
    "PASS: ActivityPlayer already supports image assets."
  );

  process.exit(0);
}

/*
 * Locate a simple JSX element whose direct text child is:
 *   {asset.value}
 *
 * This intentionally does not assume a particular className,
 * attribute ordering, indentation or whitespace.
 */
const candidatePattern =
  /<([A-Za-z][A-Za-z0-9]*)\b([^<>]*?)>\s*\{asset\.value\}\s*<\/\1>/g;

const matches =
  [...source.matchAll(
    candidatePattern
  )];

if (
  matches.length === 0
) {
  console.error(
    "Could not locate a direct JSX renderer for {asset.value}."
  );

  process.exit(2);
}

if (
  matches.length > 1
) {
  console.error(
    `Refusing ambiguous patch: found ${matches.length} direct renderers for {asset.value}.`
  );

  process.exit(3);
}

const match =
  matches[0];

const replacement =
`{asset.type === "image" ? (
                  <img
                    src={asset.value}
                    alt=""
                    aria-hidden="true"
                    draggable={false}
                    className="h-28 w-28 select-none object-contain sm:h-32 sm:w-32"
                  />
                ) : (
                  ${match[0]}
                )}`;

source =
  source.slice(
    0,
    match.index
  ) +
  replacement +
  source.slice(
    match.index +
    match[0].length
  );

fs.writeFileSync(
  file,
  source.replace(/\n+$/, "") + "\n",
  "utf8"
);

const verify =
  fs.readFileSync(
    file,
    "utf8"
  );

const required = [
  'asset.type === "image"',
  'src={asset.value}',
  '{asset.value}'
];

for (
  const token
  of required
) {
  if (
    !verify.includes(
      token
    )
  ) {
    console.error(
      `Post-patch verification failed: missing ${token}`
    );

    process.exit(4);
  }
}

console.log(
  "PASS: ActivityPlayer image/emoji rendering reconciled safely."
);
'@

WriteText $tempPatch $patchSource

& node $tempPatch $playerPath

if ($LASTEXITCODE -ne 0) {
  throw "Could not reconcile ActivityPlayer image rendering."
}

Remove-Item $tempPatch -Force -ErrorAction SilentlyContinue
Log "PASS: ActivityPlayer reconciliation"

# ------------------------------------------------------------------
# Validate the immediate package before rerunning the full phase.
# ------------------------------------------------------------------

Log ""
Log "==> Learner web typecheck"

& pnpm --filter learner-web typecheck

if ($LASTEXITCODE -ne 0) {
  throw "learner-web typecheck failed after ActivityPlayer repair."
}

Log "PASS: learner-web typecheck"

# ------------------------------------------------------------------
# Rerun original Phase 007D.
# Its existing guard:
#   if (s.includes('asset.type === "image"')) process.exit(0);
# now makes its previous fragile patch a no-op.
# ------------------------------------------------------------------

Log ""
Log "==> Re-running Phase 007D"

$args = @(
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  $phasePath
)

if ($Commit) {
  $args += "-Commit"
}

& powershell.exe @args

if ($LASTEXITCODE -ne 0) {
  throw "Phase 007D still failed with exit code $LASTEXITCODE."
}

Log ""
Log "PHASE 007D REPAIR V3: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007D REPAIR V3: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Log: $log" -ForegroundColor DarkGray
