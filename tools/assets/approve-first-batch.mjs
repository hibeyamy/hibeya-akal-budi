import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

if (
  process.argv[2] !==
  "I_REVIEWED_THE_VISUALS"
) {
  console.error(
    "Approval blocked. After visually reviewing the first batch, run:"
  );

  console.error(
    "pnpm assets:first-batch:approve I_REVIEWED_THE_VISUALS"
  );

  process.exit(1);
}

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow"
];

for (const id of ids) {
  const manifestPath =
    path.join(
      root,
      "assets",
      "manifests",
      `${id}.json`
    );

  const m =
    JSON.parse(
      fs.readFileSync(
        manifestPath,
        "utf8"
      )
    );

  m.commercialRightsConfirmed =
    true;

  m.originalityReviewed =
    true;

  m.childSafetyReviewed =
    true;

  if (
    m.culturalReviewRequired ===
    true
  ) {
    console.error(
      `${id}: cultural review is required; batch auto-approval cannot continue.`
    );

    process.exit(1);
  }

  m.status =
    "production";

  m.commercialReady =
    true;

  m.replacementRequiredForCommercialRelease =
    false;

  m.reviewedBy =
    "HIBEYA owner visual review";

  m.reviewedAt =
    new Date().toISOString();

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      m,
      null,
      2
    ) + "\n",
    "utf8"
  );

  const briefPath =
    path.join(
      root,
      "assets",
      "briefs",
      `${id}.json`
    );

  if (fs.existsSync(briefPath)) {
    const b =
      JSON.parse(
        fs.readFileSync(
          briefPath,
          "utf8"
        )
      );

    b.status =
      "production";

    fs.writeFileSync(
      briefPath,
      JSON.stringify(
        b,
        null,
        2
      ) + "\n",
      "utf8"
    );
  }
}

console.log(
  "FIRST ORIGINAL ASSET BATCH: APPROVED FOR PRODUCTION"
);
