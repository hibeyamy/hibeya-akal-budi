param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$tools = Join-Path $root "tools\assets"
$briefRoot = Join-Path $root "assets\briefs"
$queueRoot = Join-Path $root "assets\production-queue"

New-Item -ItemType Directory -Force -Path $logs,$tools,$briefRoot,$queueRoot | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007c-$runId.log"

function WriteText([string]$Path,[string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path,$Content.TrimEnd()+"`n",[Text.UTF8Encoding]::new($false))
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8

  $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
  $out = Join-Path $logs "phase007c-$stamp-out.log"
  $err = Join-Path $logs "phase007c-$stamp-err.log"

  $p = Start-Process "cmd.exe" `
    -ArgumentList @("/d","/s","/c",$Command) `
    -WorkingDirectory $root `
    -RedirectStandardOutput $out `
    -RedirectStandardError $err `
    -NoNewWindow `
    -Wait `
    -PassThru

  $o = if (Test-Path $out) { Get-Content $out -Raw } else { "" }
  $e = if (Test-Path $err) { Get-Content $err -Raw } else { "" }

  if ($o) { Write-Host $o; Add-Content $log $o -Encoding UTF8 }
  if ($e) { Write-Host $e; Add-Content $log $e -Encoding UTF8 }

  if ($p.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase007c-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 007C: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007C" -ForegroundColor Cyan
Write-Host "Original Production Asset Pipeline" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# Production brief schema
# ------------------------------------------------------------

$schema = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://hibeya.local/schemas/asset-production-brief.schema.json",
  "title": "HIBEYA Asset Production Brief",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schemaVersion",
    "assetId",
    "curriculumPurpose",
    "ageBands",
    "subject",
    "interactionRole",
    "visualBrief",
    "malaysianContext",
    "culturalReviewRequired",
    "variants",
    "masterFormat",
    "runtimeFormats",
    "productionMethod",
    "status"
  ],
  "properties": {
    "schemaVersion": { "const": 1 },
    "assetId": {
      "type": "string",
      "pattern": "^[a-z0-9]+(?:-[a-z0-9]+)*$"
    },
    "curriculumPurpose": { "type": "string", "minLength": 3 },
    "ageBands": {
      "type": "array",
      "minItems": 1,
      "uniqueItems": true,
      "items": { "enum": ["4-5", "6-7", "8-9"] }
    },
    "subject": { "type": "string", "minLength": 2 },
    "interactionRole": {
      "enum": [
        "learning-object",
        "context-object",
        "environment",
        "character",
        "feedback",
        "reward",
        "symbol"
      ]
    },
    "visualBrief": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "description",
        "composition",
        "background",
        "avoid"
      ],
      "properties": {
        "description": { "type": "string", "minLength": 10 },
        "composition": { "type": "string", "minLength": 5 },
        "background": { "type": "string", "minLength": 2 },
        "avoid": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "malaysianContext": {
      "type": "array",
      "items": { "type": "string" }
    },
    "culturalReviewRequired": { "type": "boolean" },
    "variants": {
      "type": "array",
      "minItems": 1,
      "uniqueItems": true,
      "items": { "type": "string" }
    },
    "masterFormat": { "const": "svg" },
    "runtimeFormats": {
      "type": "array",
      "minItems": 1,
      "uniqueItems": true,
      "items": { "enum": ["svg", "webp", "png"] }
    },
    "productionMethod": {
      "enum": [
        "original-internal",
        "original-ai-assisted",
        "commissioned-original"
      ]
    },
    "status": {
      "enum": [
        "draft",
        "review",
        "approved-master",
        "production"
      ]
    }
  }
}
'@
WriteText (Join-Path $tools "asset-production-brief.schema.json") $schema

# ------------------------------------------------------------
# Generate queue from Phase 007A manifests.
# No images are generated here: this produces deterministic briefs
# and keeps commercial approval human-controlled.
# ------------------------------------------------------------

$generator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const manifestRoot = path.join(root, "assets", "manifests");
const briefRoot = path.join(root, "assets", "briefs");
const queueRoot = path.join(root, "assets", "production-queue");

fs.mkdirSync(briefRoot, { recursive: true });
fs.mkdirSync(queueRoot, { recursive: true });

const files = fs.readdirSync(manifestRoot)
  .filter(file => file.endsWith(".json"))
  .sort();

const queue = [];

for (const file of files) {
  const manifest = JSON.parse(
    fs.readFileSync(path.join(manifestRoot, file), "utf8")
  );

  if (manifest.replacementRequiredForCommercialRelease !== true) continue;

  const existing = path.join(briefRoot, `${manifest.id}.json`);

  if (!fs.existsSync(existing)) {
    const subject =
      manifest.id
        .replace(/^obj-/, "")
        .replaceAll("-", " ");

    const brief = {
      schemaVersion: 1,
      assetId: manifest.id,
      curriculumPurpose:
        `Replace prototype ${manifest.id} with an original HIBEYA production asset.`,
      ageBands: ["4-5", "6-7"],
      subject,
      interactionRole: "learning-object",
      visualBrief: {
        description:
          `Original child-readable HIBEYA illustration of ${subject}, designed as a clear learning object.`,
        composition:
          "Single dominant object with strong silhouette and generous negative space.",
        background:
          "transparent",
        avoid: [
          "text",
          "logos",
          "watermarks",
          "protected characters",
          "celebrity likenesses",
          "photorealistic clutter",
          "unnecessary decorative detail"
        ]
      },
      malaysianContext: [],
      culturalReviewRequired: false,
      variants: ["default"],
      masterFormat: "svg",
      runtimeFormats: ["svg", "webp"],
      productionMethod: "original-ai-assisted",
      status: "draft"
    };

    fs.writeFileSync(
      existing,
      JSON.stringify(brief, null, 2) + "\n",
      "utf8"
    );
  }

  queue.push({
    assetId: manifest.id,
    manifest: `assets/manifests/${manifest.id}.json`,
    brief: `assets/briefs/${manifest.id}.json`,
    priority: "replace-prototype",
    status: "brief-ready"
  });
}

const queueFile = path.join(queueRoot, "learner-core.json");

fs.writeFileSync(
  queueFile,
  JSON.stringify({
    schemaVersion: 1,
    queueId: "learner-core",
    generatedFrom: "assets/manifests",
    items: queue
  }, null, 2) + "\n",
  "utf8"
);

console.log(`ASSET PRODUCTION QUEUE: ${queue.length} replacement assets`);
'@
WriteText (Join-Path $tools "generate-production-queue.mjs") $generator

# ------------------------------------------------------------
# Queue + brief validator without adding another dependency.
# ------------------------------------------------------------

$validator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const briefRoot = path.join(root, "assets", "briefs");
const queuePath = path.join(root, "assets", "production-queue", "learner-core.json");
const failures = [];

const allowedAge = new Set(["4-5", "6-7", "8-9"]);
const allowedRole = new Set([
  "learning-object",
  "context-object",
  "environment",
  "character",
  "feedback",
  "reward",
  "symbol"
]);
const allowedMethod = new Set([
  "original-internal",
  "original-ai-assisted",
  "commissioned-original"
]);
const allowedStatus = new Set([
  "draft",
  "review",
  "approved-master",
  "production"
]);

function fail(message) {
  failures.push(message);
  console.error(`ASSET PIPELINE ERROR: ${message}`);
}

if (!fs.existsSync(queuePath)) fail("Production queue is missing");

const briefs = fs.readdirSync(briefRoot)
  .filter(file => file.endsWith(".json"))
  .sort();

if (briefs.length === 0) fail("No production briefs exist");

for (const file of briefs) {
  let b;
  try {
    b = JSON.parse(fs.readFileSync(path.join(briefRoot, file), "utf8"));
  } catch {
    fail(`${file}: invalid JSON`);
    continue;
  }

  if (b.schemaVersion !== 1) fail(`${file}: invalid schemaVersion`);
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(b.assetId ?? "")) fail(`${file}: invalid assetId`);
  if (file !== `${b.assetId}.json`) fail(`${file}: filename/id mismatch`);
  if (!Array.isArray(b.ageBands) || !b.ageBands.length || b.ageBands.some(x => !allowedAge.has(x))) fail(`${file}: invalid ageBands`);
  if (!allowedRole.has(b.interactionRole)) fail(`${file}: invalid interactionRole`);
  if (!b.visualBrief?.description || b.visualBrief.description.length < 10) fail(`${file}: visual description missing`);
  if (!Array.isArray(b.visualBrief?.avoid)) fail(`${file}: avoid list missing`);
  if (b.masterFormat !== "svg") fail(`${file}: masterFormat must be svg`);
  if (!Array.isArray(b.runtimeFormats) || !b.runtimeFormats.length) fail(`${file}: runtimeFormats missing`);
  if (!allowedMethod.has(b.productionMethod)) fail(`${file}: invalid productionMethod`);
  if (!allowedStatus.has(b.status)) fail(`${file}: invalid status`);
}

if (fs.existsSync(queuePath)) {
  const q = JSON.parse(fs.readFileSync(queuePath, "utf8"));
  if (q.schemaVersion !== 1) fail("Queue schemaVersion invalid");
  if (!Array.isArray(q.items)) fail("Queue items missing");

  for (const item of q.items ?? []) {
    const brief = path.join(root, item.brief);
    const manifest = path.join(root, item.manifest);
    if (!fs.existsSync(brief)) fail(`${item.assetId}: queue brief missing`);
    if (!fs.existsSync(manifest)) fail(`${item.assetId}: provenance manifest missing`);
  }
}

if (failures.length) process.exit(1);

console.log(
  `ASSET PRODUCTION PIPELINE: PASS (${briefs.length} briefs)`
);
'@
WriteText (Join-Path $tools "validate-production-pipeline.mjs") $validator

# ------------------------------------------------------------
# Approval helper: intentionally explicit; it does not assert rights
# or originality automatically. It only advances a brief after the
# human review fields are supplied in the provenance manifest.
# ------------------------------------------------------------

$approval = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const id = process.argv[2];

if (!id) {
  console.error("Usage: pnpm assets:approve <asset-id>");
  process.exit(1);
}

const briefPath = path.join(root, "assets", "briefs", `${id}.json`);
const manifestPath = path.join(root, "assets", "manifests", `${id}.json`);

if (!fs.existsSync(briefPath) || !fs.existsSync(manifestPath)) {
  console.error(`Unknown asset: ${id}`);
  process.exit(1);
}

const brief = JSON.parse(fs.readFileSync(briefPath, "utf8"));
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

const required = [
  "commercialRightsConfirmed",
  "originalityReviewed",
  "childSafetyReviewed"
];

const incomplete = required.filter(key => manifest[key] !== true);

if (
  manifest.culturalReviewRequired === true &&
  manifest.culturalReviewed !== true
) {
  incomplete.push("culturalReviewed");
}

if (incomplete.length) {
  console.error(
    `ASSET APPROVAL BLOCKED: ${id}; incomplete provenance checks: ${incomplete.join(", ")}`
  );
  process.exit(1);
}

brief.status = "approved-master";

fs.writeFileSync(
  briefPath,
  JSON.stringify(brief, null, 2) + "\n",
  "utf8"
);

console.log(`ASSET APPROVAL: ${id} -> approved-master`);
'@
WriteText (Join-Path $tools "approve-asset.mjs") $approval

$doc = @'
# Phase 007C — Production Asset Pipeline

Phase 007C converts prototype-replacement requirements into deterministic production briefs.

## Commands

Generate/reconcile the queue:

```powershell
pnpm assets:queue
```

Validate all briefs and queue references:

```powershell
pnpm assets:pipeline:validate
```

After a human reviewer has completed the provenance checks for an asset:

```powershell
pnpm assets:approve <asset-id>
```

## Important boundary

The system does **not** automatically mark AI-generated artwork as original, safe or commercially approved.

Those judgements remain explicit review gates.

## Next production loop

For each queued asset:

1. review/edit the generated brief;
2. create original artwork;
3. save the editable master under `assets/masters`;
4. export runtime variants under `assets/exports`;
5. update the Phase 007A provenance manifest;
6. complete human review;
7. run `pnpm assets:approve <asset-id>`;
8. integrate into `@akal-budi/assets`;
9. run accessibility and visual-regression gates.

This pipeline can later be batch-driven without weakening the commercial approval controls.
'@
WriteText (Join-Path $root "ASSET_PRODUCTION_PIPELINE.md") $doc

# ------------------------------------------------------------
# Root commands
# ------------------------------------------------------------

$editor = Join-Path $env:TEMP "hibeya-phase007c-package.cjs"
WriteText $editor @'
const fs = require("fs");
const p = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(p, "utf8"));
pkg.scripts ??= {};
pkg.scripts["assets:queue"] =
  "node tools/assets/generate-production-queue.mjs";
pkg.scripts["assets:pipeline:validate"] =
  "node tools/assets/validate-production-pipeline.mjs";
pkg.scripts["assets:approve"] =
  "node tools/assets/approve-asset.mjs";
fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n", "utf8");
'@

& node $editor (Join-Path $root "package.json")
if ($LASTEXITCODE -ne 0) { throw "package.json update failed" }
Remove-Item $editor -Force -ErrorAction SilentlyContinue

Run "Generate production queue" "pnpm assets:queue"
Run "Production pipeline validation" "pnpm assets:pipeline:validate"
Run "Illustration system validation" "pnpm illustration:validate"
Run "Asset provenance validation" "pnpm assets:validate"
Run "Design policy validation" "pnpm design:validate"
Run "Design adoption validation" "pnpm design:apps:validate"
Run "Content compiler check" "pnpm content:check"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Accessibility regression" "pnpm qa:a11y"
Run "Visual regression verification" "pnpm qa:visual"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Curriculum source validation" "pnpm curriculum:sources:validate"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 007C" "git add assets/briefs assets/production-queue tools/assets ASSET_PRODUCTION_PIPELINE.md package.json"
  Run "Commit Phase 007C" 'git commit -m "feat: add original asset production pipeline"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007C: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Next: Phase 007D first commercial HIBEYA asset batch." -ForegroundColor Cyan
