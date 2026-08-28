param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$tools = Join-Path $root "tools\assets"
$manifests = Join-Path $root "assets\manifests"
$masters = Join-Path $root "assets\masters"
$runtime = Join-Path $root "packages\assets\src\generated"

New-Item -ItemType Directory -Force -Path $logs,$backups,$tools,$manifests,$masters,$runtime | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007i-$runId.log"

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
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase007i-$stamp-out.log"
  $err = Join-Path $logs "phase007i-$stamp-err.log"

  $p = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $o = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $e = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($o) {
    Write-Host $o
    Add-Content $log $o -Encoding UTF8
  }

  if ($e) {
    Write-Host $e
    Add-Content $log $e -Encoding UTF8
  }

  if ($p.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase007i-$stamp-$($Name.Replace(' ','-')).log"

    WriteText `
      $diag `
      "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"

    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 007I: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007I" -ForegroundColor Cyan
Write-Host "Automated Runtime Image Optimisation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------
# 1. Install free/open-source image tooling.
# ------------------------------------------------------------------

Run "Install Sharp image optimiser" "pnpm add -Dw sharp"

# ------------------------------------------------------------------
# 2. Optimiser: preserve approved PNG master, create WebP runtime.
# ------------------------------------------------------------------

$optimiser = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import sharp from "sharp";

const root = process.cwd();

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

const MAX_EDGE = 640;
const WEBP_QUALITY = 82;
const TARGET_MAX_BYTES = 450 * 1024;

function sha256(file) {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(file))
    .digest("hex");
}

for (const id of ids) {
  const manifestPath =
    path.join(root,"assets","manifests",`${id}.json`);

  if (!fs.existsSync(manifestPath)) {
    throw new Error(`${id}: manifest missing`);
  }

  const manifest =
    JSON.parse(
      fs.readFileSync(manifestPath,"utf8")
    );

  if (
    manifest.status !== "production" ||
    manifest.commercialReady !== true
  ) {
    throw new Error(
      `${id}: optimisation requires an approved production asset`
    );
  }

  const master =
    path.join(
      root,
      "assets",
      "masters",
      `${id}.png`
    );

  if (!fs.existsSync(master)) {
    throw new Error(
      `${id}: approved PNG master missing`
    );
  }

  const output =
    path.join(
      root,
      "packages",
      "assets",
      "src",
      "generated",
      `${id}.webp`
    );

  const before =
    await sharp(master)
      .metadata();

  await sharp(master)
    .rotate()
    .resize({
      width: MAX_EDGE,
      height: MAX_EDGE,
      fit: "inside",
      withoutEnlargement: true
    })
    .webp({
      quality: WEBP_QUALITY,
      effort: 5,
      smartSubsample: true
    })
    .toFile(output);

  const after =
    await sharp(output)
      .metadata();

  const runtimeBytes =
    fs.statSync(output)
      .size;

  if (runtimeBytes > TARGET_MAX_BYTES) {
    throw new Error(
      `${id}: runtime WebP is ${runtimeBytes} bytes; exceeds ${TARGET_MAX_BYTES}`
    );
  }

  manifest.runtime = {
    ...(manifest.runtime ?? {}),
    file:
      `packages/assets/src/generated/${id}.webp`
  };

  manifest.runtimeOptimisation = {
    sourceMaster:
      `assets/masters/${id}.png`,

    sourceSha256:
      sha256(master),

    runtimeSha256:
      sha256(output),

    masterDimensions: {
      width:
        before.width ?? null,

      height:
        before.height ?? null
    },

    runtimeDimensions: {
      width:
        after.width ?? null,

      height:
        after.height ?? null
    },

    runtimeFormat:
      "webp",

    quality:
      WEBP_QUALITY,

    maxEdge:
      MAX_EDGE,

    runtimeBytes
  };

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      manifest,
      null,
      2
    ) + "\n",
    "utf8"
  );

  console.log(
    `${id}: PNG ${fs.statSync(master).size} -> WebP ${runtimeBytes} bytes (${after.width}x${after.height})`
  );
}

console.log(
  "RUNTIME IMAGE OPTIMISATION: PASS"
);
'@

WriteText (Join-Path $tools "optimise-hibiscus-runtime.mjs") $optimiser

# ------------------------------------------------------------------
# 3. Deterministic validation of generated runtime files.
# ------------------------------------------------------------------

$validator = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import sharp from "sharp";

const root = process.cwd();

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

const failures = [];

function hash(file) {
  return crypto
    .createHash("sha256")
    .update(fs.readFileSync(file))
    .digest("hex");
}

for (const id of ids) {
  const manifestPath =
    path.join(root,"assets","manifests",`${id}.json`);

  const manifest =
    JSON.parse(
      fs.readFileSync(manifestPath,"utf8")
    );

  const master =
    path.join(root,"assets","masters",`${id}.png`);

  const runtime =
    path.join(root,"packages","assets","src","generated",`${id}.webp`);

  if (!fs.existsSync(master)) {
    failures.push(`${id}: PNG master missing`);
    continue;
  }

  if (!fs.existsSync(runtime)) {
    failures.push(`${id}: WebP runtime missing`);
    continue;
  }

  if (
    manifest.runtime?.file !==
    `packages/assets/src/generated/${id}.webp`
  ) {
    failures.push(`${id}: manifest runtime path is not WebP`);
  }

  if (
    manifest.runtimeOptimisation?.sourceSha256 !==
    hash(master)
  ) {
    failures.push(`${id}: master hash mismatch`);
  }

  if (
    manifest.runtimeOptimisation?.runtimeSha256 !==
    hash(runtime)
  ) {
    failures.push(`${id}: runtime hash mismatch`);
  }

  const metadata =
    await sharp(runtime)
      .metadata();

  if (metadata.format !== "webp") {
    failures.push(`${id}: runtime is not WebP`);
  }

  if (
    (metadata.width ?? 0) > 640 ||
    (metadata.height ?? 0) > 640
  ) {
    failures.push(`${id}: runtime dimensions exceed 640px`);
  }

  if (
    fs.statSync(runtime).size >
    450 * 1024
  ) {
    failures.push(`${id}: runtime exceeds 450KB`);
  }

  if (
    manifest.status !== "production" ||
    manifest.commercialReady !== true
  ) {
    failures.push(`${id}: optimisation changed approval state`);
  }
}

if (failures.length) {
  for (const failure of failures) {
    console.error(`RUNTIME OPTIMISATION ERROR: ${failure}`);
  }

  process.exit(1);
}

console.log(
  "RUNTIME OPTIMISATION VALIDATION: PASS"
);
'@

WriteText (Join-Path $tools "validate-hibiscus-runtime-optimisation.mjs") $validator

# ------------------------------------------------------------------
# 4. Runtime budget report.
# ------------------------------------------------------------------

$report = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

let masterTotal = 0;
let runtimeTotal = 0;

console.log("");
console.log("HIBISCUS IMAGE BUDGET");
console.log("=====================");

for (const id of ids) {
  const master =
    path.join(root,"assets","masters",`${id}.png`);

  const runtime =
    path.join(root,"packages","assets","src","generated",`${id}.webp`);

  const masterBytes =
    fs.statSync(master).size;

  const runtimeBytes =
    fs.statSync(runtime).size;

  masterTotal += masterBytes;
  runtimeTotal += runtimeBytes;

  const saving =
    100 -
    (
      runtimeBytes /
      masterBytes *
      100
    );

  console.log(
    `${id.padEnd(20)} master=${(masterBytes/1024).toFixed(0).padStart(5)}KB  runtime=${(runtimeBytes/1024).toFixed(0).padStart(4)}KB  saving=${saving.toFixed(1)}%`
  );
}

console.log("---------------------");
console.log(
  `TOTAL master=${(masterTotal/1024/1024).toFixed(2)}MB runtime=${(runtimeTotal/1024/1024).toFixed(2)}MB`
);

console.log(
  `TOTAL saving=${(100-runtimeTotal/masterTotal*100).toFixed(1)}%`
);
'@

WriteText (Join-Path $tools "report-hibiscus-image-budget.mjs") $report

# ------------------------------------------------------------------
# 5. Root scripts.
# ------------------------------------------------------------------

$packagePath = Join-Path $root "package.json"
Backup $packagePath

$temp = Join-Path $env:TEMP "hibeya-phase007i-package.cjs"

WriteText $temp @'
const fs = require("fs");
const p = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(p,"utf8"));

pkg.scripts ??= {};

pkg.scripts["assets:hibiscus:optimise"] =
  "node tools/assets/optimise-hibiscus-runtime.mjs";

pkg.scripts["assets:hibiscus:optimise:validate"] =
  "node tools/assets/validate-hibiscus-runtime-optimisation.mjs";

pkg.scripts["assets:hibiscus:budget"] =
  "node tools/assets/report-hibiscus-image-budget.mjs";

pkg.scripts["assets:hibiscus:runtime:qa"] =
  "pnpm assets:hibiscus:optimise:validate && pnpm assets:formats:validate && pnpm assets:runtime:check && pnpm assets:runtime:validate";

fs.writeFileSync(
  p,
  JSON.stringify(pkg,null,2)+"\n",
  "utf8"
);
'@

& node $temp $packagePath
if ($LASTEXITCODE -ne 0) {
  throw "package.json update failed"
}

Remove-Item $temp -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------------
# 6. Optimise and rebuild all downstream generated state.
# ------------------------------------------------------------------

Run "Optimise approved hibiscus runtime images" "pnpm assets:hibiscus:optimise"
Run "Runtime optimisation validation" "pnpm assets:hibiscus:optimise:validate"
Run "Image budget report" "pnpm assets:hibiscus:budget"
Run "Compile commercial runtime registry" "pnpm assets:runtime:compile"
Run "Runtime registry reproducibility" "pnpm assets:runtime:check"
Run "Runtime format validation" "pnpm assets:formats:validate"
Run "Commercial runtime validation" "pnpm assets:runtime:validate"
Run "Commercial asset validation" "pnpm assets:commercial:validate"
Run "Asset provenance validation" "pnpm assets:validate"
Run "Asset production pipeline validation" "pnpm assets:pipeline:validate"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression verification" "pnpm qa:visual"
Run "Content compiler check" "pnpm content:check"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Curriculum source validation" "pnpm curriculum:sources:validate"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run `
    "Stage Phase 007I" `
    "git add assets/manifests packages/assets/src/generated tools/assets package.json pnpm-lock.yaml"

  Run `
    "Commit Phase 007I" `
    'git commit -m "perf: optimise approved hibiscus runtime assets"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007I: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "High-quality PNG masters remain preserved." -ForegroundColor Cyan
Write-Host "The application now receives optimised WebP runtime assets." -ForegroundColor Cyan
