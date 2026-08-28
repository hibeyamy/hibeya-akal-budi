import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();

const ids = [
  "apple-red",
  "apple-green",
  "banana-yellow"
];

for (const id of ids) {
  const manifestPath =
    path.join(root, "assets", "manifests", `${id}.json`);

  if (!fs.existsSync(manifestPath)) {
    console.error(`Missing provenance manifest: ${id}`);
    process.exit(1);
  }

  const m =
    JSON.parse(
      fs.readFileSync(
        manifestPath,
        "utf8"
      )
    );

  m.status =
    "review";

  m.currentRepresentation =
    "svg";

  m.sourceType =
    "original-internal";

  m.creator =
    "HIBEYA deterministic vector production";

  m.sourceFile =
    `assets/masters/${id}.svg`;

  m.sourceValue =
    null;

  m.commercialRightsConfirmed =
    false;

  m.originalityReviewed =
    false;

  m.childSafetyReviewed =
    false;

  m.commercialReady =
    false;

  m.replacementRequiredForCommercialRelease =
    true;

  m.notes =
    "Original HIBEYA SVG candidate created in Phase 007D. Human visual/originality/rights/child-safety review is still required before commercial approval.";

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

  if (
    fs.existsSync(
      briefPath
    )
  ) {
    const b =
      JSON.parse(
        fs.readFileSync(
          briefPath,
          "utf8"
        )
      );

    b.productionMethod =
      "original-internal";

    b.status =
      "review";

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
  "FIRST ASSET BATCH: review candidates prepared"
);
