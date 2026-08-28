import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

if (
  process.argv[2] !==
  "I_REVIEWED_VISUALS_AND_CULTURE"
) {
  console.error(
    "Approval blocked."
  );

  console.error(
    "After reviewing visual quality AND Malaysian cultural context, run:"
  );

  console.error(
    "pnpm assets:hibiscus-batch:approve I_REVIEWED_VISUALS_AND_CULTURE"
  );

  process.exit(1);
}

const ids = [
  "hibiscus-red",
  "hibiscus-yellow",
  "hibiscus-purple"
];

for (const id of ids) {
  const manifestPath =
    path.join(
      root,
      "assets",
      "manifests",
      `${id}.json`
    );

  const manifest =
    JSON.parse(
      fs.readFileSync(
        manifestPath,
        "utf8"
      )
    );

  manifest.commercialRightsConfirmed =
    true;

  manifest.originalityReviewed =
    true;

  manifest.childSafetyReviewed =
    true;

  manifest.culturalReviewed =
    true;

  manifest.status =
    "production";

  manifest.commercialReady =
    true;

  manifest.replacementRequiredForCommercialRelease =
    false;

  manifest.reviewedBy =
    "HIBEYA owner visual and cultural review";

  manifest.reviewedAt =
    new Date().toISOString();

  fs.writeFileSync(
    manifestPath,
    JSON.stringify(
      manifest,
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
    const brief =
      JSON.parse(
        fs.readFileSync(
          briefPath,
          "utf8"
        )
      );

    brief.status =
      "production";

    fs.writeFileSync(
      briefPath,
      JSON.stringify(
        brief,
        null,
        2
      ) + "\n",
      "utf8"
    );
  }
}

const family = {
  schemaVersion:
    1,

  id:
    "malaysian-garden-hibiscus",

  version:
    "1.0.0",

  title:
    "Malaysian Garden Hibiscus",

  purpose:
    "Commercial HIBEYA hibiscus assets for Malaysian-context learner activities.",

  commercialReleaseRequiresHumanApproval:
    true,

  members:
    ids.map(
      id => ({
        id,
        master:
          `assets/masters/${id}.svg`,
        export:
          `assets/exports/${id}.svg`,
        runtime:
          `packages/assets/src/generated/${id}.svg`
      })
    )
};

fs.writeFileSync(
  path.join(
    root,
    "assets",
    "families",
    "malaysian-garden-hibiscus.json"
  ),
  JSON.stringify(
    family,
    null,
    2
  ) + "\n",
  "utf8"
);

console.log(
  "HIBISCUS BATCH: APPROVED FOR PRODUCTION"
);
