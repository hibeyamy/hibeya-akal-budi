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
