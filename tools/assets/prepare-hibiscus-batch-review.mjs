import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const metadata = {
  "hibiscus-red": {
    alt: {
      ms: "Bunga raya merah",
      en: "Red hibiscus"
    }
  },
  "hibiscus-yellow": {
    alt: {
      ms: "Bunga raya kuning",
      en: "Yellow hibiscus"
    }
  },
  "hibiscus-purple": {
    alt: {
      ms: "Bunga raya ungu",
      en: "Purple hibiscus"
    }
  }
};

for (const [id, data] of Object.entries(metadata)) {
  const manifestPath =
    path.join(
      root,
      "assets",
      "manifests",
      `${id}.json`
    );

  if (!fs.existsSync(manifestPath)) {
    console.error(`Missing provenance manifest: ${id}`);
    process.exit(1);
  }

  const manifest =
    JSON.parse(
      fs.readFileSync(
        manifestPath,
        "utf8"
      )
    );

  manifest.status =
    "review";

  manifest.currentRepresentation =
    "svg";

  manifest.sourceType =
    "original-internal";

  manifest.creator =
    "HIBEYA deterministic vector production";

  manifest.sourceFile =
    `assets/masters/${id}.svg`;

  manifest.sourceValue =
    null;

  manifest.commercialRightsConfirmed =
    false;

  manifest.originalityReviewed =
    false;

  manifest.childSafetyReviewed =
    false;

  manifest.culturalReviewRequired =
    true;

  manifest.culturalReviewed =
    false;

  manifest.commercialReady =
    false;

  manifest.replacementRequiredForCommercialRelease =
    true;

  manifest.runtime = {
    alt:
      data.alt,

    file:
      `packages/assets/src/generated/${id}.svg`
  };

  manifest.notes =
    "Original HIBEYA hibiscus SVG candidate created in Phase 007G. Human visual, originality, child-safety, commercial-rights and Malaysian cultural-context review are required before approval.";

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

    brief.productionMethod =
      "original-internal";

    brief.status =
      "review";

    brief.malaysianContext =
      [
        "bunga raya",
        "Malaysian national flower context"
      ];

    brief.culturalReviewRequired =
      true;

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

console.log(
  "HIBISCUS BATCH: review state prepared"
);
