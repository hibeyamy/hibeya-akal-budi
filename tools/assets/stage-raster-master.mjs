import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import sharp from "sharp";

const root = process.cwd();
const [, , assetId, inputPath] = process.argv;

if (!assetId || !inputPath) {
  console.error(
    "Usage: node tools/assets/stage-raster-master.mjs <asset-id> <png-file>"
  );
  process.exit(1);
}

const planPath = path.join(
  root,
  "packages/assets/source/visual-replacement-plan.json"
);

const plan = JSON.parse(
  await fs.readFile(planPath, "utf8")
);

const candidate =
  plan.assets.find(
    item => item.id === assetId
  );

if (!candidate) {
  throw new Error(
    `Asset is not in the governed replacement plan: ${assetId}`
  );
}

const absoluteInput =
  path.resolve(root, inputPath);

const metadata =
  await sharp(absoluteInput).metadata();

if (metadata.format !== "png") {
  throw new Error(
    `${assetId}: replacement source must be PNG`
  );
}

if (
  !metadata.width ||
  !metadata.height ||
  metadata.width < candidate.minimumWidth ||
  metadata.height < candidate.minimumHeight
) {
  throw new Error(
    `${assetId}: PNG must be at least ` +
    `${candidate.minimumWidth}x${candidate.minimumHeight}`
  );
}

const reviewDir = path.join(
  root,
  "packages/assets/source/review/fruit"
);

await fs.mkdir(
  reviewDir,
  {
    recursive: true
  }
);

const target =
  path.join(
    reviewDir,
    `${assetId}.png`
  );

await fs.copyFile(
  absoluteInput,
  target
);

const reviewRecord = {
  id: assetId,
  stagedAt:
    new Date().toISOString(),
  state:
    "visual-review-required",
  sourcePath:
    path.relative(
      root,
      target
    ).replaceAll(
      path.sep,
      "/"
    ),
  width:
    metadata.width,
  height:
    metadata.height,
  hasAlpha:
    metadata.hasAlpha === true,
  semanticIdStable:
    true,
  productionEnabled:
    false,
  originalityReviewed:
    false,
  visualReviewed:
    false,
  notes:
    "Staging does not promote or publish the artwork."
};

await fs.writeFile(
  path.join(
    reviewDir,
    `${assetId}.review.json`
  ),
  JSON.stringify(
    reviewRecord,
    null,
    2
  ) + "\n",
  "utf8"
);

console.log(
  `STAGED: ${reviewRecord.sourcePath}`
);

console.log(
  "MANUAL VISUAL REVIEW REQUIRED"
);
