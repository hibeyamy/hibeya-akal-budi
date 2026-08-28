import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const base = path.join(root, "design", "illustration");

const required = [
  "illustration-system.json",
  "STYLE_BIBLE.md",
  "PRODUCTION_WORKFLOW.md",
  "asset-brief.template.json"
];

const failures = [];

for (const file of required) {
  const target = path.join(base, file);
  if (!fs.existsSync(target)) failures.push(`Missing ${file}`);
}

let spec;
try {
  spec = JSON.parse(
    fs.readFileSync(path.join(base, "illustration-system.json"), "utf8")
  );
} catch {
  failures.push("illustration-system.json is invalid JSON");
}

if (spec) {
  if (spec.schemaVersion !== 1) failures.push("Unsupported illustration schemaVersion");
  if (!spec.ageBands?.["4-5"]) failures.push("Missing age band 4-5");
  if (!spec.ageBands?.["6-7"]) failures.push("Missing age band 6-7");
  if (!spec.ageBands?.["8-9"]) failures.push("Missing age band 8-9");
  if (spec.production?.preferredMaster !== "svg") failures.push("Preferred master must be svg");
  if (spec.learning?.colourOnlyMeaningForbidden !== true) failures.push("Colour-only meaning policy must be enabled");
  if (spec.characters?.protectedCharactersForbidden !== true) failures.push("Protected-character policy must be enabled");
}

let brief;
try {
  brief = JSON.parse(
    fs.readFileSync(path.join(base, "asset-brief.template.json"), "utf8")
  );
} catch {
  failures.push("asset-brief.template.json is invalid JSON");
}

if (brief) {
  for (const key of [
    "assetId",
    "curriculumPurpose",
    "ageBands",
    "subject",
    "interactionRole",
    "variants",
    "masterFormat",
    "runtimeFormats",
    "status"
  ]) {
    if (brief[key] === undefined) failures.push(`Asset brief missing ${key}`);
  }
}

if (failures.length) {
  for (const failure of failures) console.error(`ILLUSTRATION SYSTEM ERROR: ${failure}`);
  process.exit(1);
}

console.log("ILLUSTRATION SYSTEM VALIDATION: PASS");
