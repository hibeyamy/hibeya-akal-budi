param(
  [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Get-Location).Path
$workspacePath = Join-Path $repoRoot "pnpm-workspace.yaml"
$phasePath = Join-Path $repoRoot "phase006b-v7.ps1"
$logsRoot = Join-Path $repoRoot "tools\dev\logs"
$backupRoot = Join-Path $repoRoot "tools\dev\backups"

New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$sessionLog = Join-Path $logsRoot "phase006b-v9-repair-$runId.log"

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Content
  )

  $dir = Split-Path -Parent $Path

  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  [System.IO.File]::WriteAllText(
    $Path,
    $Content.TrimEnd() + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Log {
  param([string]$Message)

  Write-Host $Message

  Add-Content `
    -Path $sessionLog `
    -Value $Message `
    -Encoding UTF8
}

trap {
  $details = @"
PHASE 006B V9 REPAIR FAILED

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

  Write-Utf8NoBom `
    -Path $sessionLog `
    -Content $details

  Write-Host ""
  Write-Host "Phase 006B V9 repair failed." -ForegroundColor Red
  Write-Host "Diagnostic: $sessionLog" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 006B REPAIR V9" -ForegroundColor Cyan
Write-Host "Minimal parser-safe pnpm build approval repair" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

Log "START $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

if (-not (Test-Path $workspacePath)) {
  throw "pnpm-workspace.yaml not found: $workspacePath"
}

if (-not (Test-Path $phasePath)) {
  throw "phase006b-v7.ps1 not found in repository root."
}

Log ""
Log "==> Backing up pnpm-workspace.yaml"

$backupPath = Join-Path $backupRoot "$runId-pnpm-workspace.yaml"
Copy-Item $workspacePath $backupPath -Force

Log "Backup created: $backupPath"

Log ""
Log "==> Applying esbuild-only build approval"

$tempEditor = Join-Path $env:TEMP "akal-budi-pnpm-workspace-editor.cjs"

$editorSource = @'
const fs = require("fs");

const file = process.argv[2];

if (!file) {
  console.error("workspace path missing");
  process.exit(2);
}

let text = fs.readFileSync(file, "utf8");

if (/^dangerouslyAllowAllBuilds\s*:\s*true\s*$/m.test(text)) {
  console.error("Unsafe setting detected: dangerouslyAllowAllBuilds: true");
  process.exit(3);
}

const lines = text.replace(/\r\n/g, "\n").split("\n");

let allowIndex = lines.findIndex((line) =>
  /^allowBuilds\s*:\s*$/.test(line)
);

if (allowIndex === -1) {
  while (lines.length > 0 && lines[lines.length - 1] === "") {
    lines.pop();
  }

  lines.push("");
  lines.push("allowBuilds:");
  lines.push("  esbuild: true");
} else {
  let endIndex = lines.length;

  for (let i = allowIndex + 1; i < lines.length; i += 1) {
    if (/^[A-Za-z0-9_-][A-Za-z0-9_-]*\s*:/.test(lines[i])) {
      endIndex = i;
      break;
    }
  }

  let esbuildIndex = -1;

  for (let i = allowIndex + 1; i < endIndex; i += 1) {
    if (/^\s+["']?esbuild(?:@[^"']+)?["']?\s*:/.test(lines[i])) {
      esbuildIndex = i;
      break;
    }
  }

  if (esbuildIndex >= 0) {
    lines[esbuildIndex] = "  esbuild: true";
  } else {
    lines.splice(allowIndex + 1, 0, "  esbuild: true");
  }
}

const output =
  lines.join("\n").replace(/\n+$/, "") + "\n";

fs.writeFileSync(file, output, "utf8");

const verify = fs.readFileSync(file, "utf8");

if (!/^allowBuilds\s*:\s*\n(?:[ \t]+.*\n)*?[ \t]+esbuild\s*:\s*true\s*$/m.test(verify)) {
  console.error("Could not verify allowBuilds.esbuild=true");
  process.exit(4);
}

console.log("PASS: allowBuilds.esbuild=true");
'@

Write-Utf8NoBom `
  -Path $tempEditor `
  -Content $editorSource

& node $tempEditor $workspacePath

if ($LASTEXITCODE -ne 0) {
  throw "Failed to update pnpm-workspace.yaml safely."
}

Remove-Item $tempEditor -Force -ErrorAction SilentlyContinue

Log "PASS: pnpm build approval updated"

Log ""
Log "==> Running pnpm install under approved policy"

& pnpm install

if ($LASTEXITCODE -ne 0) {
  throw "pnpm install failed after approving esbuild."
}

Log "PASS: pnpm install"

Log ""
Log "==> Re-running complete Phase 006B V7"

$arguments = @(
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  $phasePath
)

if ($Commit) {
  $arguments += "-Commit"
}

& powershell.exe @arguments

$phaseExitCode = $LASTEXITCODE

if ($phaseExitCode -ne 0) {
  throw "Phase 006B V7 failed with exit code $phaseExitCode."
}

Log ""
Log "PHASE 006B REPAIR V9: PASS $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 006B REPAIR V9: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Diagnostic log: $sessionLog" -ForegroundColor DarkGray
