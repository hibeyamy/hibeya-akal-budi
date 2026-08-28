param([switch]$Commit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$logs = Join-Path $root "tools\dev\logs"
$backups = Join-Path $root "tools\dev\backups"
$tools = Join-Path $root "tools\assets"
$families = Join-Path $root "assets\families"
$runId = Get-Date -Format "yyyyMMdd-HHmmssfff"
$log = Join-Path $logs "phase007e-$runId.log"

New-Item -ItemType Directory -Force -Path $logs,$backups,$tools,$families | Out-Null

function WriteText([string]$Path,[string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  [IO.File]::WriteAllText($Path,$Content.TrimEnd()+"`n",[Text.UTF8Encoding]::new($false))
}

function Backup([string]$Path) {
  if (-not (Test-Path $Path)) { return }
  $relative = $Path.Substring($root.Length).TrimStart("\")
  Copy-Item $Path (Join-Path $backups "$runId-$($relative.Replace('\','__'))") -Force
}

function Run([string]$Name,[string]$Command) {
  Write-Host ""
  Write-Host "==> $Name" -ForegroundColor Cyan
  Add-Content $log "`n==> $Name`n$Command" -Encoding UTF8
  & cmd.exe /d /s /c $Command
  if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE" }
  Write-Host "PASS: $Name" -ForegroundColor Green
}

trap {
  Add-Content $log "`nFAILED`n$($_ | Out-String)`n$($_.ScriptStackTrace)" -Encoding UTF8
  Write-Host ""
  Write-Host "PHASE 007E: FAILED" -ForegroundColor Red
  Write-Host "Log: $log" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "HIBEYA AKAL BUDI - PHASE 007E" -ForegroundColor Cyan
Write-Host "Scalable Asset-Family Production Foundation" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Approved 007D assets become fixtures; 007E does not regenerate artwork.
$family = @'
{
  "schemaVersion": 1,
  "id": "learner-core-fruit",
  "version": "1.0.0",
  "title": "Learner Core Fruit",
  "purpose": "Approved Phase 007D fixtures for validating scalable family infrastructure.",
  "commercialReleaseRequiresHumanApproval": true,
  "members": [
    {
      "id": "apple-red",
      "master": "assets/masters/apple-red.svg",
      "export": "assets/exports/apple-red.svg",
      "runtime": "packages/assets/src/generated/apple-red.svg"
    },
    {
      "id": "apple-green",
      "master": "assets/masters/apple-green.svg",
      "export": "assets/exports/apple-green.svg",
      "runtime": "packages/assets/src/generated/apple-green.svg"
    },
    {
      "id": "banana-yellow",
      "master": "assets/masters/banana-yellow.svg",
      "export": "assets/exports/banana-yellow.svg",
      "runtime": "packages/assets/src/generated/banana-yellow.svg"
    }
  ]
}
'@
WriteText (Join-Path $families "learner-core-fruit.json") $family

$validator = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const familyDir = path.join(root, "assets", "families");
const failures = [];
const idsAcrossFamilies = new Map();

function hash(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function fail(message) {
  failures.push(message);
}

if (!fs.existsSync(familyDir)) fail("assets/families is missing");

const files = fs.existsSync(familyDir)
  ? fs.readdirSync(familyDir).filter(f => f.endsWith(".json")).sort()
  : [];

if (!files.length) fail("no asset-family specifications found");

for (const file of files) {
  let family;
  try {
    family = JSON.parse(fs.readFileSync(path.join(familyDir,file),"utf8"));
  } catch (error) {
    fail(`${file}: invalid JSON (${error.message})`);
    continue;
  }

  if (family.schemaVersion !== 1) fail(`${file}: schemaVersion must be 1`);
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(family.id ?? ""))
    fail(`${file}: invalid family id`);
  if (!/^\d+\.\d+\.\d+$/.test(family.version ?? ""))
    fail(`${file}: version must use semantic x.y.z`);
  if (family.commercialReleaseRequiresHumanApproval !== true)
    fail(`${file}: human commercial approval gate must remain enabled`);
  if (!Array.isArray(family.members) || !family.members.length) {
    fail(`${file}: members must be a non-empty array`);
    continue;
  }

  const local = new Set();

  for (const member of family.members) {
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(member.id ?? ""))
      fail(`${file}: invalid member id ${member.id}`);

    if (local.has(member.id)) fail(`${file}: duplicate member ${member.id}`);
    local.add(member.id);

    if (idsAcrossFamilies.has(member.id))
      fail(`${member.id}: also declared by ${idsAcrossFamilies.get(member.id)}`);
    else
      idsAcrossFamilies.set(member.id,file);

    const expected = {
      master: `assets/masters/${member.id}.svg`,
      export: `assets/exports/${member.id}.svg`,
      runtime: `packages/assets/src/generated/${member.id}.svg`
    };

    for (const key of Object.keys(expected)) {
      if (member[key] !== expected[key])
        fail(`${member.id}: ${key} path must be ${expected[key]}`);
    }

    const paths = Object.values(expected).map(p => path.join(root,p));
    for (const p of paths) if (!fs.existsSync(p)) fail(`${member.id}: missing ${path.relative(root,p)}`);

    if (paths.every(fs.existsSync)) {
      if (new Set(paths.map(hash)).size !== 1)
        fail(`${member.id}: master/export/runtime hashes differ`);

      const svg = fs.readFileSync(paths[0],"utf8");
      if (!svg.includes("<svg") || !svg.includes("viewBox="))
        fail(`${member.id}: SVG lacks required root/viewBox`);
      if (/<script\b/i.test(svg) || /\bon[a-z]+\s*=/i.test(svg) || /<foreignObject\b/i.test(svg))
        fail(`${member.id}: SVG contains unsafe executable/foreign content`);
      if (/\b(?:href|xlink:href)\s*=\s*["'](?:https?:|data:|javascript:)/i.test(svg))
        fail(`${member.id}: SVG contains external/data/javascript reference`);
    }

    const manifestPath = path.join(root,"assets","manifests",`${member.id}.json`);
    if (!fs.existsSync(manifestPath)) {
      fail(`${member.id}: provenance manifest missing`);
    } else {
      const manifest = JSON.parse(fs.readFileSync(manifestPath,"utf8"));
      if (manifest.commercialReady !== true)
        fail(`${member.id}: approved fixture is not commercialReady`);
      if (manifest.originalityReviewed !== true)
        fail(`${member.id}: originality review not recorded`);
      if (manifest.childSafetyReviewed !== true)
        fail(`${member.id}: child-safety review not recorded`);
      if (manifest.commercialRightsConfirmed !== true)
        fail(`${member.id}: commercial rights confirmation not recorded`);
    }
  }
}

if (failures.length) {
  for (const f of failures) console.error(`ASSET FAMILY ERROR: ${f}`);
  process.exit(1);
}

console.log(`ASSET FAMILY VALIDATION: PASS (${files.length} families, ${idsAcrossFamilies.size} assets)`);
'@
WriteText (Join-Path $tools "validate-families.mjs") $validator

$compiler = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const familyDir = path.join(root,"assets","families");
const outFile = path.join(root,"packages","assets","src","generated","familyCatalogue.ts");

function hash(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

const families = fs.readdirSync(familyDir)
  .filter(f => f.endsWith(".json"))
  .sort()
  .map(file => JSON.parse(fs.readFileSync(path.join(familyDir,file),"utf8")));

const compiled = families.map(family => ({
  id: family.id,
  version: family.version,
  title: family.title,
  members: family.members.map(member => ({
    id: member.id,
    sha256: hash(path.join(root,member.master))
  }))
}));

const banner = `// GENERATED FILE. DO NOT EDIT.
// Source: assets/families/*.json

`;

const body =
  banner +
  `export const assetFamilyCatalogue = ${JSON.stringify(compiled,null,2)} as const;\n\n` +
  `export type AssetFamilyId = typeof assetFamilyCatalogue[number]["id"];\n`;

const check = process.argv.includes("--check");

if (check) {
  if (!fs.existsSync(outFile) || fs.readFileSync(outFile,"utf8") !== body) {
    console.error("ASSET FAMILY COMPILER CHECK: generated catalogue is out of date");
    process.exit(1);
  }
  console.log("ASSET FAMILY COMPILER CHECK: PASS");
} else {
  fs.mkdirSync(path.dirname(outFile),{recursive:true});
  fs.writeFileSync(outFile,body,"utf8");
  console.log(`ASSET FAMILY COMPILER: ${compiled.length} families compiled`);
}
'@
WriteText (Join-Path $tools "compile-families.mjs") $compiler

$reporter = @'
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const dir = path.join(root,"assets","families");
const families = fs.readdirSync(dir).filter(f => f.endsWith(".json")).sort();

for (const file of families) {
  const f = JSON.parse(fs.readFileSync(path.join(dir,file),"utf8"));
  console.log(`${f.id}@${f.version}`);
  for (const m of f.members) {
    const manifest = JSON.parse(
      fs.readFileSync(path.join(root,"assets","manifests",`${m.id}.json`),"utf8")
    );
    console.log(`  ${m.id.padEnd(22)} ${manifest.status.padEnd(12)} commercial=${manifest.commercialReady === true ? "yes" : "no"}`);
  }
}
'@
WriteText (Join-Path $tools "report-families.mjs") $reporter

# Patch package scripts idempotently.
$packagePath = Join-Path $root "package.json"
Backup $packagePath
$temp = Join-Path $env:TEMP "hibeya-phase007e-package.cjs"
WriteText $temp @'
const fs = require("fs");
const p = process.argv[2];
const pkg = JSON.parse(fs.readFileSync(p,"utf8"));
pkg.scripts ??= {};
pkg.scripts["assets:families:compile"] = "node tools/assets/compile-families.mjs";
pkg.scripts["assets:families:check"] = "node tools/assets/compile-families.mjs --check";
pkg.scripts["assets:families:validate"] = "node tools/assets/validate-families.mjs";
pkg.scripts["assets:families:report"] = "node tools/assets/report-families.mjs";
pkg.scripts["assets:families:qa"] = "pnpm assets:families:validate && pnpm assets:families:check && pnpm assets:validate && pnpm assets:pipeline:validate";
fs.writeFileSync(p,JSON.stringify(pkg,null,2)+"\n","utf8");
'@
& node $temp $packagePath
if ($LASTEXITCODE -ne 0) { throw "package.json update failed" }
Remove-Item $temp -Force -ErrorAction SilentlyContinue

Run "Asset family validation" "pnpm assets:families:validate"
Run "Compile family catalogue" "pnpm assets:families:compile"
Run "Compiler reproducibility check" "pnpm assets:families:check"
Run "Asset provenance validation" "pnpm assets:validate"
Run "Asset production pipeline validation" "pnpm assets:pipeline:validate"
Run "Illustration system validation" "pnpm illustration:validate"
Run "Asset package typecheck" "pnpm --filter @akal-budi/assets typecheck"
Run "Repository typecheck" "pnpm typecheck"
Run "All tests" "pnpm test"
Run "Production build" "pnpm build"
Run "Content compiler check" "pnpm content:check"
Run "Curriculum validation" "pnpm curriculum:validate"
Run "Curriculum source validation" "pnpm curriculum:sources:validate"
Run "Git whitespace check" "git diff --check"

if ($Commit) {
  Run "Stage Phase 007E" "git add assets/families tools/assets packages/assets/src/generated/familyCatalogue.ts package.json"
  Run "Commit Phase 007E" 'git commit -m "feat: add scalable asset family pipeline"'
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "PHASE 007E: PASS" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "No new artwork was created or approved in this phase." -ForegroundColor Cyan
Write-Host "Approved Phase 007D assets were used only as pipeline fixtures." -ForegroundColor Cyan
