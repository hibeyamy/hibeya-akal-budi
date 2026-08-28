import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const inbox = path.join(root,"assets","inbox","hibiscus");
const spec = JSON.parse(fs.readFileSync(path.join(inbox,"batch.json"),"utf8"));

const allowed = new Set(spec.allowedExtensions.map(x => `.${x}`));

for (const asset of spec.assets) {
  const matches = fs.readdirSync(inbox)
    .filter(file => path.parse(file).name === asset.id)
    .filter(file => allowed.has(path.extname(file).toLowerCase()));

  if (matches.length !== 1) {
    console.error(`${asset.id}: expected exactly one candidate file`);
    process.exit(1);
  }

  const file = matches[0];
  const ext = path.extname(file).slice(1).toLowerCase();
  const source = path.join(inbox,file);

  const master = path.join(root,"assets","masters",file);
  const runtime = path.join(root,"packages","assets","src","generated",file);

  fs.copyFileSync(source,master);
  fs.copyFileSync(source,runtime);

  const manifestPath = path.join(root,"assets","manifests",`${asset.id}.json`);

  if (!fs.existsSync(manifestPath)) {
    console.error(`${asset.id}: provenance manifest missing`);
    process.exit(1);
  }

  const manifest = JSON.parse(fs.readFileSync(manifestPath,"utf8"));

  manifest.status = "review";
  manifest.currentRepresentation = ext;
  manifest.sourceType = "original-ai-assisted";
  manifest.creator = "HIBEYA visual-production workflow";
  manifest.sourceFile = `assets/masters/${file}`;
  manifest.sourceValue = null;

  manifest.commercialRightsConfirmed = false;
  manifest.originalityReviewed = false;
  manifest.childSafetyReviewed = false;

  manifest.culturalReviewRequired = asset.culturalReviewRequired === true;
  manifest.culturalReviewed = false;

  manifest.commercialReady = false;
  manifest.replacementRequiredForCommercialRelease = true;

  manifest.runtime = {
    file: `packages/assets/src/generated/${file}`,
    alt: asset.alt
  };

  manifest.notes =
    "Artwork ingested from the HIBEYA visual-production intake. Human visual, originality, commercial-rights, child-safety and cultural review remain mandatory before commercial approval.";

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(manifest,null,2) + "\n",
    "utf8"
  );

  const reviewRecord = {
    schemaVersion: 1,
    assetId: asset.id,
    candidateFile: `assets/inbox/hibiscus/${file}`,
    masterFile: `assets/masters/${file}`,
    runtimeFile: `packages/assets/src/generated/${file}`,
    status: "pending-human-review",
    checks: {
      visualQuality: false,
      recognisableAsHibiscus: false,
      childSuitable: false,
      originalityReviewed: false,
      commercialRightsConfirmed: false,
      culturalReviewed: false
    }
  };

  fs.writeFileSync(
    path.join(root,"assets","review","hibiscus",`${asset.id}.json`),
    JSON.stringify(reviewRecord,null,2) + "\n",
    "utf8"
  );
}

console.log("HIBISCUS BATCH INGEST: COMPLETE");
console.log("STATUS: pending human review");
