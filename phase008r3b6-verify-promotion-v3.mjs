import fs from "node:fs";
import path from "node:path";

const file = path.join(process.cwd(), "content", "activity-manifests", "beza-bunga-raya-001.json");
const doc = JSON.parse(fs.readFileSync(file, "utf8"));

const checks = [
  ["originalityReviewed", doc.activity?.provenance?.originalityReviewed === true],
  ["culturalReviewed", doc.activity?.provenance?.culturalReviewed === true],
  ["reviewedBy", doc.activity?.provenance?.reviewedBy === "HilmiBeya"],
  ["reviewedAt", !Number.isNaN(Date.parse(doc.activity?.provenance?.reviewedAt ?? ""))],
  ["metadata.active", doc.activity?.metadata?.active === true],
  ["catalogue.enabled", doc.catalogue?.enabled === true]
];

for (const [name, ok] of checks) {
  if (!ok) throw new Error(`${name} verification failed`);
  console.log(`PASS: ${name}`);
}

const correct = doc.activity.options.filter(x => x.correct === true);
if (correct.length !== 1 || correct[0].asset !== "hibiscus-yellow") {
  throw new Error("Reviewed answer contract changed unexpectedly");
}
console.log("PASS: answer contract preserved");
