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
