param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$tools = Join-Path $root "tools\assets"
$design = Join-Path $root "design\illustration"

New-Item -ItemType Directory -Force -Path $logs,$backups,$tools,$design | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007h-$runId.log"

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
  $out = Join-Path $logs "phase007h-$stamp-out.log"
  $err = Join-Path $logs "phase007h-$stamp-err.log"

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

  if ($o) { Write-Host $o; Add-Content $log $o -Encoding UTF8 }
  if ($e) { Write-Host $e; Add-Content $log $e -Encoding UTF8 }

  if ($p.ExitCode -ne 0) {
    $diag = Join-Path $logs "FAILED-phase007h-$stamp-$($Name.Replace(' ','-')).log"
    WriteText $diag "COMMAND:`n$Command`n`nEXIT CODE:`n$($p.ExitCode)`n`nSTDOUT:`n$o`n`nSTDERR:`n$e"
    throw "$Name failed with exit code $($p.ExitCode). Diagnostic: $diag"
  }

  Remove-Item $out,$err -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 007H: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007H" -ForegroundColor Cyan
Write-Host "Format-Agnostic Commercial Asset Pipeline" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$policy = @'
{
  "schemaVersion": 1,
  "defaultStrategy": "best-format-for-purpose",
  "formats": {
    "svg": {
      "useFor": ["simple-icons","basic-shapes","logos","flat-vector-symbols"],
      "masterAllowed": true,
      "runtimeAllowed": true
    },
    "png": {
      "useFor": ["transparent-raster-illustrations","high-fidelity-master-artwork","manual-review-assets"],
      "masterAllowed": true,
      "runtimeAllowed": true
    },
    "webp": {
      "useFor": ["production-runtime-illustrations","complex-scenes","optimised-transparent-assets"],
      "masterAllowed": false,
      "runtimeAllowed": true
    },
    "jpg": {
      "useFor": ["photographic-backgrounds"],
      "masterAllowed": false,
      "runtimeAllowed": true
    }
  },
  "preferredRuntimeForIllustration": "webp",
  "preferredMasterForRasterIllustration": "png",
  "preferredMasterForSimpleVector": "svg",
  "humanVisualApprovalRequired": true,
  "commercialRightsApprovalRequired": true,
  "culturalReviewWhenRelevant": true,
  "aiGeneratedAssetsMustNotSelfApprove": true
}
'@

WriteText (Join-Path $design "asset-format-policy.json") $policy

$briefSchemaPath = Join-Path $tools "asset-production-brief.schema.json"
if (-not (Test-Path $briefSchemaPath)) {
  throw "Missing prerequisite: $briefSchemaPath"
}

Backup $briefSchemaPath

$schemaUpdater = @'
import fs from "node:fs";

const file = process.argv[2];
const schema = JSON.parse(fs.readFileSync(file,"utf8"));

schema.properties ??= {};

schema.properties.masterFormat = {
  enum: ["svg","png"]
};

schema.properties.runtimeFormats = {
  type: "array",
  minItems: 1,
  uniqueItems: true,
  items: {
    enum: ["svg","png","webp","jpg"]
  }
};

fs.writeFileSync(file,JSON.stringify(schema,null,2)+"\n","utf8");
console.log("ASSET BRIEF SCHEMA: format-agnostic policy applied");
'@

$tempUpdater = Join-Path $env:TEMP "hibeya-phase007h-schema.mjs"
WriteText $tempUpdater $schemaUpdater
& node $tempUpdater $briefSchemaPath
if ($LASTEXITCODE -ne 0) { throw "Could not update asset brief schema." }
Remove-Item $tempUpdater -Force -ErrorAction SilentlyContinue

$runtimeValidator = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const manifestRoot = path.join(root,"assets","manifests");
const allowed = new Set([".svg",".png",".webp",".jpg",".jpeg"]);
const failures = [];

for (const file of fs.readdirSync(manifestRoot).filter(f => f.endsWith(".json")).sort()) {
  const manifest = JSON.parse(fs.readFileSync(path.join(manifestRoot,file),"utf8"));
  if (manifest.commercialReady !== true) continue;

  const runtimeFile = manifest.runtime?.file;

  if (!runtimeFile) {
    failures.push(`${manifest.id}: approved asset missing runtime.file`);
    continue;
  }

  const absolute = path.join(root,runtimeFile);

  if (!fs.existsSync(absolute)) {
    failures.push(`${manifest.id}: runtime file missing (${runtimeFile})`);
    continue;
  }

  const ext = path.extname(runtimeFile).toLowerCase();

  if (!allowed.has(ext)) {
    failures.push(`${manifest.id}: unsupported runtime extension ${ext}`);
  }

  if (fs.statSync(absolute).size <= 0) {
    failures.push(`${manifest.id}: empty runtime file`);
  }

  if (ext === ".svg") {
    const svg = fs.readFileSync(absolute,"utf8");

    if (!svg.includes("<svg")) {
      failures.push(`${manifest.id}: invalid SVG root`);
    }

    if (/<script\b/i.test(svg) || /\bon[a-z]+\s*=/i.test(svg) || /<foreignObject\b/i.test(svg)) {
      failures.push(`${manifest.id}: unsafe SVG content`);
    }
  }
}

if (failures.length) {
  for (const failure of failures) console.error(`ASSET FORMAT ERROR: ${failure}`);
  process.exit(1);
}

console.log("ASSET FORMAT VALIDATION: PASS");
'@

WriteText (Join-Path $tools "validate-runtime-formats.mjs") $runtimeValidator

$compilerPath = Join-Path $tools "compile-commercial-registry.mjs"
if (-not (Test-Path $compilerPath)) {
  throw "Missing prerequisite: $compilerPath"
}

Backup $compilerPath

$compiler = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const manifestRoot = path.join(root,"assets","manifests");
const output = path.join(root,"packages","assets","src","generated","commercialRegistry.generated.ts");

const approved = [];

for (const file of fs.readdirSync(manifestRoot).filter(f => f.endsWith(".json")).sort()) {
  const manifest = JSON.parse(fs.readFileSync(path.join(manifestRoot,file),"utf8"));

  if (manifest.commercialReady !== true) continue;

  const id = manifest.id;
  const runtimeFile = manifest.runtime?.file;
  const alt = manifest.runtime?.alt;

  if (!runtimeFile || !alt?.ms || !alt?.en) {
    console.error(`${id}: commercial asset is missing runtime metadata`);
    process.exit(1);
  }

  const expectedPrefix = "packages/assets/src/generated/";

  if (!runtimeFile.startsWith(expectedPrefix)) {
    console.error(`${id}: runtime file must be inside ${expectedPrefix}`);
    process.exit(1);
  }

  const absolute = path.join(root,runtimeFile);

  if (!fs.existsSync(absolute)) {
    console.error(`${id}: runtime asset file does not exist`);
    process.exit(1);
  }

  approved.push({
    id,
    fileName: path.basename(runtimeFile),
    alt
  });
}

const lines = [
  "// GENERATED FILE. DO NOT EDIT.",
  "// Source: assets/manifests/*.json where commercialReady=true",
  "",
  "export const generatedCommercialAssetOverrides = {"
];

for (const asset of approved) {
  lines.push(`  ${JSON.stringify(asset.id)}: {`);
  lines.push(`    id: ${JSON.stringify(asset.id)},`);
  lines.push('    type: "image" as const,');
  lines.push("    value: new URL(");
  lines.push(`      ${JSON.stringify(`./${asset.fileName}`)},`);
  lines.push("      import.meta.url");
  lines.push("    ).href,");
  lines.push("    alt: {");
  lines.push(`      ms: ${JSON.stringify(asset.alt.ms)},`);
  lines.push(`      en: ${JSON.stringify(asset.alt.en)}`);
  lines.push("    }");
  lines.push("  },");
}

lines.push("} as const;");
lines.push("");
lines.push("export type GeneratedCommercialAssetId =");
lines.push('  keyof typeof generatedCommercialAssetOverrides;');
lines.push("");

const body = lines.join("\n") + "\n";
const check = process.argv.includes("--check");

if (check) {
  if (!fs.existsSync(output) || fs.readFileSync(output,"utf8") !== body) {
    console.error("COMMERCIAL REGISTRY CHECK: generated output is out of date");
    process.exit(1);
  }

  console.log(`COMMERCIAL REGISTRY CHECK: PASS (${approved.length} approved assets)`);
  process.exit(0);
}

fs.mkdirSync(path.dirname(output),{recursive:true});
fs.writeFileSync(output,body,"utf8");
console.log(`COMMERCIAL REGISTRY: ${approved.length} approved assets compiled`);
'@

WriteText $compilerPath $compiler

$ingest = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const [, , id, source, runtimeFormat] = process.argv;

if (!id || !source || !runtimeFormat) {
  console.error("Usage: pnpm assets:ingest <asset-id> <source-file> <svg|png|webp|jpg>");
  process.exit(1);
}

if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(id)) {
  console.error("Asset id must use kebab-case.");
  process.exit(1);
}

const allowed = new Set(["svg","png","webp","jpg"]);

if (!allowed.has(runtimeFormat)) {
  console.error(`Unsupported runtime format: ${runtimeFormat}`);
  process.exit(1);
}

const sourcePath = path.resolve(root,source);

if (!fs.existsSync(sourcePath)) {
  console.error(`Source file does not exist: ${source}`);
  process.exit(1);
}

const runtimeFile = path.join(
  root,
  "packages",
  "assets",
  "src",
  "generated",
  `${id}.${runtimeFormat}`
);

fs.mkdirSync(path.dirname(runtimeFile),{recursive:true});
fs.copyFileSync(sourcePath,runtimeFile);

const manifestPath = path.join(root,"assets","manifests",`${id}.json`);

if (fs.existsSync(manifestPath)) {
  const manifest = JSON.parse(fs.readFileSync(manifestPath,"utf8"));
  manifest.runtime ??= {};
  manifest.runtime.file = `packages/assets/src/generated/${id}.${runtimeFormat}`;
  manifest.status = "review";
  manifest.commercialReady = false;
  manifest.replacementRequiredForCommercialRelease = true;
  manifest.notes =
    "Asset ingested into runtime review state. Human visual/originality/rights/child-safety review is required before commercial approval.";

  fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+"\n","utf8");
}

console.log(`ASSET INGEST: ${id} -> ${path.relative(root,runtimeFile)}`);
console.log("STATUS: review; no commercial approval was granted automatically");
'@

WriteText (Join-Path $tools "ingest-asset.mjs") $ingest

$doc = @'
# HIBEYA Asset Format Strategy

HIBEYA does not require every production asset to be SVG.

## Preferred formats

### SVG
Use for simple icons, geometric learning shapes, logos and flat vector symbols.

### PNG
Use for high-quality transparent illustration masters and manually refined raster artwork.

### WebP
Preferred runtime format for fruits, animals, characters, Malaysian cultural objects, detailed learning illustrations and complex scenes.

### JPG
Use only when transparency is unnecessary, primarily photographic/background material.

## Workflow

```text
Asset brief
â†’ choose correct creative tool
â†’ create high-quality master
â†’ human visual review
â†’ ingest
â†’ provenance review
â†’ optimise runtime format
â†’ automated registry compilation
â†’ Storybook/product review
â†’ commercial approval
```

Automation may generate briefs, validate files, copy/optimise exports, update runtime paths, compile registries and run QA.

Automation must not self-declare visual quality, originality, commercial rights or cultural suitability.
'@

WriteText (Join-Path $root "ASSET_FORMAT_STRATEGY.md") $doc

$packagePath = Join-Path $root "package.json"
Backup $packagePath

$temp = Join-Path $env:TEMP "hibeya-phase007h-package.cjs"

WriteText $temp @'
const fs = require("fs");
const p = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(p,"utf8"));

pkg.scripts ??= {};
pkg.scripts["assets:formats:validate"] = "node tools/assets/validate-runtime-formats.mjs";
pkg.scripts["assets:ingest"] = "node tools/assets/ingest-asset.mjs";
pkg.scripts["assets:formats:qa"] = "pnpm assets:formats:validate && pnpm assets:runtime:check && pnpm assets:runtime:validate";

fs.writeFileSync(p,JSON.stringify(pkg,null,2)+"\n","utf8");
'@

& node $temp $packagePath

if ($LASTEXITCODE -ne 0) {
  throw "package.json update failed"
}

Remove-Item $temp -Force -ErrorAction SilentlyContinue

Run "Compile commercial runtime registry" "pnpm assets:runtime:compile"
Run "Runtime registry reproducibility" "pnpm assets:runtime:check"
Run "Runtime format validation" "pnpm assets:formats:validate"
Run "Commercial runtime validation" "pnpm assets:runtime:validate"
Run "Asset family QA" "pnpm assets:families:qa"
Run "Asset production pipeline validation" "pnpm assets:pipeline:validate"
Run "Illustration system validation" "pnpm illustration:validate"
Run "Asset package typecheck" "pnpm --filter @akal-budi/assets typecheck"
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
  Run "Stage Phase 007H" "git add design/illustration tools/assets ASSET_FORMAT_STRATEGY.md package.json packages/assets/src/generated/commercialRegistry.generated.ts"
  Run "Commit Phase 007H" 'git commit -m "feat: make commercial asset pipeline format agnostic"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007H: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "SVG is no longer mandatory for commercial illustration assets." -ForegroundColor Cyan
Write-Host "Next: use visual-production tools for complex artwork and ingest reviewed outputs." -ForegroundColor Cyan
