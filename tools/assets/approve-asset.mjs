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
