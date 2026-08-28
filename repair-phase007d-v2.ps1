param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$indexPath = Join-Path $root "packages\assets\src\index.ts"
$phasePath = Join-Path $root "phase007d-first-original-asset-batch.ps1"

New-Item -ItemType Directory -Force -Path $logs,$backups | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007d-repair-v2-$runId.log"

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
PHASE 007D REPAIR V2 FAILED

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
  Write-Host "PHASE 007D REPAIR V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007D REPAIR V2" -ForegroundColor Cyan
Write-Host "AST-lite getAsset reconciliation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $indexPath)) {
  throw "Asset registry not found: $indexPath"
}

if (-not (Test-Path $phasePath)) {
  throw "Phase 007D installer not found: $phasePath"
}

$backup = Join-Path $backups "$runId-packages__assets__src__index.ts"
Copy-Item $indexPath $backup -Force
Log "Backup: $backup"

$tempPatch = Join-Path $env:TEMP "hibeya-phase007d-repair-assets.cjs"

$patch = @'
const fs = require("fs");

const file = process.argv[2];

let source =
  fs.readFileSync(
    file,
    "utf8"
  ).replace(/\r\n/g, "\n");

const importLine =
  'import { commercialAssetOverrides } from "./commercial";';

if (
  !source.includes(
    'from "./commercial"'
  )
) {
  source =
    importLine +
    "\n\n" +
    source;
}

function findFunctionRange(
  text,
  functionName
) {
  const patterns = [
    new RegExp(
      `export\\s+function\\s+${functionName}\\s*\\(`
    ),
    new RegExp(
      `function\\s+${functionName}\\s*\\(`
    )
  ];

  let start =
    -1;

  for (
    const pattern
    of patterns
  ) {
    const match =
      pattern.exec(
        text
      );

    if (match) {
      start =
        match.index;

      break;
    }
  }

  if (
    start < 0
  ) {
    return null;
  }

  const openBrace =
    text.indexOf(
      "{",
      start
    );

  if (
    openBrace < 0
  ) {
    return null;
  }

  let depth =
    0;

  let quote =
    null;

  let escaped =
    false;

  let lineComment =
    false;

  let blockComment =
    false;

  for (
    let i = openBrace;
    i < text.length;
    i += 1
  ) {
    const ch =
      text[i];

    const next =
      text[i + 1];

    if (
      lineComment
    ) {
      if (
        ch === "\n"
      ) {
        lineComment =
          false;
      }

      continue;
    }

    if (
      blockComment
    ) {
      if (
        ch === "*" &&
        next === "/"
      ) {
        blockComment =
          false;

        i += 1;
      }

      continue;
    }

    if (
      quote
    ) {
      if (
        escaped
      ) {
        escaped =
          false;

        continue;
      }

      if (
        ch === "\\"
      ) {
        escaped =
          true;

        continue;
      }

      if (
        ch === quote
      ) {
        quote =
          null;
      }

      continue;
    }

    if (
      ch === "/" &&
      next === "/"
    ) {
      lineComment =
        true;

      i += 1;

      continue;
    }

    if (
      ch === "/" &&
      next === "*"
    ) {
      blockComment =
        true;

      i += 1;

      continue;
    }

    if (
      ch === '"' ||
      ch === "'" ||
      ch === "`"
    ) {
      quote =
        ch;

      continue;
    }

    if (
      ch === "{"
    ) {
      depth += 1;

      continue;
    }

    if (
      ch === "}"
    ) {
      depth -= 1;

      if (
        depth === 0
      ) {
        return {
          start,
          end:
            i + 1
        };
      }
    }
  }

  return null;
}

const range =
  findFunctionRange(
    source,
    "getAsset"
  );

if (
  !range
) {
  console.error(
    "Could not locate getAsset() function."
  );

  process.exit(2);
}

const replacement =
`export function getAsset(assetId: string): AssetDefinition {
  const asset =
    commercialAssetOverrides[assetId] ??
    assets[assetId];

  if (!asset) {
    throw new Error(\`Unknown asset: \${assetId}\`);
  }

  return asset;
}`;

source =
  source.slice(
    0,
    range.start
  ) +
  replacement +
  source.slice(
    range.end
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

if (
  !verify.includes(
    'from "./commercial"'
  ) ||
  !verify.includes(
    "commercialAssetOverrides[assetId]"
  )
) {
  console.error(
    "Post-patch verification failed."
  );

  process.exit(3);
}

console.log(
  "PASS: getAsset() reconciled safely."
);
'@

WriteText $tempPatch $patch

& node $tempPatch $indexPath

if ($LASTEXITCODE -ne 0) {
  throw "Could not reconcile packages/assets/src/index.ts"
}

Remove-Item $tempPatch -Force -ErrorAction SilentlyContinue

Log "PASS: asset registry reconciliation"

Log ""
Log "==> Running @akal-budi/assets typecheck"

& pnpm --filter @akal-budi/assets typecheck

if ($LASTEXITCODE -ne 0) {
  throw "@akal-budi/assets typecheck failed after registry repair."
}

Log "PASS: @akal-budi/assets typecheck"

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

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007D REPAIR V2: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Log: $log" -ForegroundColor DarkGray
