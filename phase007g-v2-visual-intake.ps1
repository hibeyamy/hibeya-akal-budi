param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$tools = Join-Path $root "tools\assets"
$inbox = Join-Path $root "assets\inbox\hibiscus"
$review = Join-Path $root "assets\review\hibiscus"
$masters = Join-Path $root "assets\masters"
$runtime = Join-Path $root "packages\assets\src\generated"

New-Item -ItemType Directory -Force -Path $logs,$backups,$tools,$inbox,$review,$masters,$runtime | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007g-v2-$runId.log"

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

  $p = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -NoNewWindow `
    -Wait `
    -PassThru

  if ($p.ExitCode -ne 0) {
    throw "$Name failed with exit code $($p.ExitCode). Log: $log"
  }

  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8

  Write-Host ""
  Write-Host "PHASE 007G V2: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow

  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007G V2" -ForegroundColor Cyan
Write-Host "Visual Asset Intake + Review Vault" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ============================================================
# 1. Intake specification
# ============================================================

$intakeSpec = @'
{
  "schemaVersion": 1,
  "batchId": "malaysian-garden-hibiscus",
  "description": "Format-agnostic visual intake for the first Malaysian-context hibiscus family.",
  "allowedExtensions": ["png", "webp", "svg"],
  "preferredRuntimeFormat": "webp",
  "assets": [
    {
      "id": "hibiscus-red",
      "required": true,
      "alt": {
        "ms": "Bunga raya merah",
        "en": "Red hibiscus"
      },
      "culturalReviewRequired": true
    },
    {
      "id": "hibiscus-yellow",
      "required": true,
      "alt": {
        "ms": "Bunga raya kuning",
        "en": "Yellow hibiscus"
      },
      "culturalReviewRequired": true
    },
    {
      "id": "hibiscus-purple",
      "required": true,
      "alt": {
        "ms": "Bunga raya ungu",
        "en": "Purple hibiscus"
      },
      "culturalReviewRequired": true
    }
  ]
}
'@

WriteText (Join-Path $inbox "batch.json") $intakeSpec

# ============================================================
# 2. Batch inspector
# ============================================================

$inspect = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const inbox = path.join(root,"assets","inbox","hibiscus");
const specPath = path.join(inbox,"batch.json");

const spec = JSON.parse(fs.readFileSync(specPath,"utf8"));
const allowed = new Set(spec.allowedExtensions.map(x => `.${x}`));
const failures = [];
const found = [];

for (const asset of spec.assets) {
  const matches = fs.readdirSync(inbox)
    .filter(file => path.parse(file).name === asset.id)
    .filter(file => allowed.has(path.extname(file).toLowerCase()));

  if (matches.length === 0) {
    if (asset.required) failures.push(`${asset.id}: artwork file is missing`);
    continue;
  }

  if (matches.length > 1) {
    failures.push(`${asset.id}: multiple candidate files found (${matches.join(", ")})`);
    continue;
  }

  const file = matches[0];
  const absolute = path.join(inbox,file);
  const stat = fs.statSync(absolute);

  if (stat.size <= 0) failures.push(`${asset.id}: file is empty`);

  found.push({
    id: asset.id,
    file,
    extension: path.extname(file).slice(1).toLowerCase(),
    bytes: stat.size
  });
}

if (failures.length) {
  console.error("HIBISCUS INTAKE: NOT READY");

  for (const failure of failures) {
    console.error(`- ${failure}`);
  }

  console.error("");
  console.error("Place exactly one approved candidate file for each asset in:");
  console.error("  assets/inbox/hibiscus/");
  console.error("");
  console.error("Accepted names:");
  for (const asset of spec.assets) {
    console.error(`  ${asset.id}.png OR .webp OR .svg`);
  }

  process.exit(2);
}

console.log("HIBISCUS INTAKE: READY");
for (const asset of found) {
  console.log(`- ${asset.id}: ${asset.file} (${asset.bytes} bytes)`);
}
'@

WriteText (Join-Path $tools "inspect-hibiscus-intake.mjs") $inspect

# ============================================================
# 3. Batch ingestion
# ============================================================

$ingest = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const inbox = path.join(root,"assets","inbox","hibiscus");
const spec = JSON.parse(fs.readFileSync(path.join(inbox,"batch.json"),"utf8"));

const allowed = new Set(spec.allowedExtensions.map(x => `.${x}`));

for (const asset of spec.assets) {
  const matches = fs.readdirSync(inbox)
    .filter(file => path.parse(file).name === asset.id)
    .filter(file => allowed.has(path.extname(file).toLowerCase()));

  if (matches.length !== 1) {
    console.error(`${asset.id}: expected exactly one candidate file`);
    process.exit(1);
  }

  const file = matches[0];
  const ext = path.extname(file).slice(1).toLowerCase();
  const source = path.join(inbox,file);

  const master = path.join(root,"assets","masters",file);
  const runtime = path.join(root,"packages","assets","src","generated",file);

  fs.copyFileSync(source,master);
  fs.copyFileSync(source,runtime);

  const manifestPath = path.join(root,"assets","manifests",`${asset.id}.json`);

  if (!fs.existsSync(manifestPath)) {
    console.error(`${asset.id}: provenance manifest missing`);
    process.exit(1);
  }

  const manifest = JSON.parse(fs.readFileSync(manifestPath,"utf8"));

  manifest.status = "review";
  manifest.currentRepresentation = ext;
  manifest.sourceType = "original-ai-assisted";
  manifest.creator = "HIBEYA visual-production workflow";
  manifest.sourceFile = `assets/masters/${file}`;
  manifest.sourceValue = null;

  manifest.commercialRightsConfirmed = false;
  manifest.originalityReviewed = false;
  manifest.childSafetyReviewed = false;

  manifest.culturalReviewRequired = asset.culturalReviewRequired === true;
  manifest.culturalReviewed = false;

  manifest.commercialReady = false;
  manifest.replacementRequiredForCommercialRelease = true;

  manifest.runtime = {
    file: `packages/assets/src/generated/${file}`,
    alt: asset.alt
  };

  manifest.notes =
    "Artwork ingested from the HIBEYA visual-production intake. Human visual, originality, commercial-rights, child-safety and cultural review remain mandatory before commercial approval.";

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(manifest,null,2) + "\n",
    "utf8"
  );

  const reviewRecord = {
    schemaVersion: 1,
    assetId: asset.id,
    candidateFile: `assets/inbox/hibiscus/${file}`,
    masterFile: `assets/masters/${file}`,
    runtimeFile: `packages/assets/src/generated/${file}`,
    status: "pending-human-review",
    checks: {
      visualQuality: false,
      recognisableAsHibiscus: false,
      childSuitable: false,
      originalityReviewed: false,
      commercialRightsConfirmed: false,
      culturalReviewed: false
    }
  };

  fs.writeFileSync(
    path.join(root,"assets","review","hibiscus",`${asset.id}.json`),
    JSON.stringify(reviewRecord,null,2) + "\n",
    "utf8"
  );
}

console.log("HIBISCUS BATCH INGEST: COMPLETE");
console.log("STATUS: pending human review");
'@

WriteText (Join-Path $tools "ingest-hibiscus-batch.mjs") $ingest

# ============================================================
# 4. Approval helper
# ============================================================

$approve = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

if (process.argv[2] !== "I_REVIEWED_VISUALS_RIGHTS_AND_CULTURE") {
  console.error("Approval blocked.");
  console.error("After completing human review, run:");
  console.error("pnpm assets:hibiscus:approve I_REVIEWED_VISUALS_RIGHTS_AND_CULTURE");
  process.exit(1);
}

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

for (const id of ids) {
  const manifestPath = path.join(root,"assets","manifests",`${id}.json`);
  const reviewPath = path.join(root,"assets","review","hibiscus",`${id}.json`);

  const manifest = JSON.parse(fs.readFileSync(manifestPath,"utf8"));
  const review = JSON.parse(fs.readFileSync(reviewPath,"utf8"));

  manifest.commercialRightsConfirmed = true;
  manifest.originalityReviewed = true;
  manifest.childSafetyReviewed = true;
  manifest.culturalReviewed = true;
  manifest.status = "production";
  manifest.commercialReady = true;
  manifest.replacementRequiredForCommercialRelease = false;
  manifest.reviewedBy = "HIBEYA owner";
  manifest.reviewedAt = new Date().toISOString();

  review.status = "approved";
  for (const key of Object.keys(review.checks)) {
    review.checks[key] = true;
  }
  review.approvedAt = manifest.reviewedAt;

  fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+"\n","utf8");
  fs.writeFileSync(reviewPath,JSON.stringify(review,null,2)+"\n","utf8");
}

console.log("HIBISCUS BATCH: APPROVED");
'@

WriteText (Join-Path $tools "approve-hibiscus-v2.mjs") $approve

# ============================================================
# 5. Package scripts
# ============================================================

$packagePath = Join-Path $root "package.json"
Backup $packagePath

$temp = Join-Path $env:TEMP "hibeya-phase007g-v2-package.cjs"

WriteText $temp @'
const fs = require("fs");
const p = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(p,"utf8"));

pkg.scripts ??= {};

pkg.scripts["assets:hibiscus:intake"] =
  "node tools/assets/inspect-hibiscus-intake.mjs";

pkg.scripts["assets:hibiscus:ingest"] =
  "node tools/assets/ingest-hibiscus-batch.mjs";

pkg.scripts["assets:hibiscus:approve"] =
  "node tools/assets/approve-hibiscus-v2.mjs";

pkg.scripts["assets:hibiscus:finalise"] =
  "pnpm assets:hibiscus:approve I_REVIEWED_VISUALS_RIGHTS_AND_CULTURE && pnpm assets:runtime:compile && pnpm assets:runtime:check && pnpm assets:runtime:validate && pnpm assets:commercial:validate";

fs.writeFileSync(p,JSON.stringify(pkg,null,2)+"\n","utf8");
'@

& node $temp $packagePath
if ($LASTEXITCODE -ne 0) { throw "package.json update failed." }
Remove-Item $temp -Force -ErrorAction SilentlyContinue

# ============================================================
# 6. Non-artwork QA only. Missing artwork is NOT a phase failure.
# ============================================================

Run "Runtime format validation" "pnpm assets:formats:validate"
Run "Asset production pipeline validation" "pnpm assets:pipeline:validate"
Run "Illustration system validation" "pnpm illustration:validate"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 007G V2" "git add assets/inbox assets/review tools/assets package.json"
  Run "Commit Phase 007G V2" 'git commit -m "feat: add format-agnostic hibiscus visual intake workflow"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007G V2: PASS - VISUAL INTAKE READY" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next manual creative step:" -ForegroundColor Yellow
Write-Host "Create or export 3 high-quality files into:" -ForegroundColor Cyan
Write-Host "  assets\\inbox\\hibiscus\\" -ForegroundColor White
Write-Host ""
Write-Host "Required names (exactly one format each):" -ForegroundColor Cyan
Write-Host "  hibiscus-red.png/.webp/.svg" -ForegroundColor White
Write-Host "  hibiscus-yellow.png/.webp/.svg" -ForegroundColor White
Write-Host "  hibiscus-purple.png/.webp/.svg" -ForegroundColor White
Write-Host ""
Write-Host "Then run:" -ForegroundColor Cyan
Write-Host "  pnpm assets:hibiscus:intake" -ForegroundColor White
Write-Host "  pnpm assets:hibiscus:ingest" -ForegroundColor White
Write-Host ""
Write-Host "Do NOT approve until you have visually reviewed the ingested artwork." -ForegroundColor Yellow
