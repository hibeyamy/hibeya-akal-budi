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
