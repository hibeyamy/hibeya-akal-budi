import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const file = path.join(root, "content", "activity-manifests", "beza-bunga-raya-001.json");
if (!fs.existsSync(file)) throw new Error("Activity manifest missing");

const doc = JSON.parse(fs.readFileSync(file, "utf8"));
const a = doc.activity;
const c = doc.catalogue;

if (!a || a.id !== "beza-bunga-raya-001") throw new Error("Activity contract mismatch");
if (!c || typeof c !== "object") throw new Error("Catalogue contract missing");

for (const id of ["hibiscus-red","hibiscus-yellow"]) {
  if (!JSON.stringify(a.options).includes(id)) throw new Error(`Reviewed semantic asset missing: ${id}`);
}
if (!Array.isArray(doc.skillMappings) || !doc.skillMappings.some(x => x.skillId === "visual-discrimination" && x.role === "primary")) {
  throw new Error("visual-discrimination primary skill mapping missing");
}

a.provenance.originalityReviewed = true;
a.provenance.culturalReviewed = true;
a.provenance.reviewedBy = "HilmiBeya";
a.provenance.reviewedAt = new Date().toISOString();
a.metadata.active = true;
c.enabled = true;

fs.writeFileSync(file, JSON.stringify(doc, null, 2) + "\n", "utf8");

console.log("PROMOTED: content/activity-manifests/beza-bunga-raya-001.json");
console.log("PASS: activity.provenance review fields recorded");
console.log("PASS: activity.metadata.active = true");
console.log("PASS: catalogue.enabled = true");
